const test = require('firebase-functions-test')();

jest.mock('firebase-admin', () => {
    const mockUpdate = jest.fn();
    const mockArrayRemove = jest.fn();
    const mockIncrement = jest.fn();
    
    const state = {
        mockExpiredDocs: [],
        mockQueueSnap: { exists: false, data: () => ({}) },
        mockTokenSnaps: {}
    };

    const mockTransaction = {
        get: jest.fn(async (ref) => {
            if (ref.isQueue) return state.mockQueueSnap;
            return state.mockTokenSnaps[ref.id];
        }),
        update: mockUpdate,
    };

    const mockGet = jest.fn(async () => {
        return {
            empty: state.mockExpiredDocs.length === 0,
            size: state.mockExpiredDocs.length,
            docs: state.mockExpiredDocs
        };
    });

    const firestoreMock = jest.fn(() => ({
        collectionGroup: jest.fn(() => ({
            where: jest.fn().mockReturnThis(),
            get: mockGet,
        })),
        collection: jest.fn(() => ({
            doc: jest.fn((id) => ({
                id,
                isQueue: true
            }))
        })),
        runTransaction: jest.fn(async (callback) => {
            return callback(mockTransaction);
        }),
        batch: jest.fn()
    }));
    
    firestoreMock.FieldValue = {
        serverTimestamp: () => 'SERVER_TIMESTAMP',
        arrayRemove: mockArrayRemove,
        increment: mockIncrement,
    };
    
    firestoreMock.Timestamp = {
        now: () => ({ toMillis: () => Date.now() })
    };

    return {
        initializeApp: jest.fn(),
        firestore: firestoreMock,
        messaging: jest.fn(),
        auth: jest.fn(),
        __mocks: { mockUpdate, mockArrayRemove, mockIncrement, state }
    };
});

const admin = require('firebase-admin');
const { __mocks } = admin;

const myFunctions = require('./index.js');

describe('expireReadyOrders', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        __mocks.state.mockExpiredDocs = [];
        __mocks.state.mockTokenSnaps = {};
        __mocks.state.mockQueueSnap = { exists: false, data: () => ({}) };
    });

    afterAll(() => {
        test.cleanup();
    });

    it('should transition expired ready_for_pickup token to discarded', async () => {
        const tokenId = 'token1';
        const docRef = { id: tokenId, parent: { parent: { id: 'order1' } } };
        __mocks.state.mockExpiredDocs = [{ ref: docRef, id: tokenId }];
        
        __mocks.state.mockTokenSnaps[tokenId] = {
            data: () => ({
                token_status: 'ready_for_pickup',
                collection_deadline: { toMillis: () => Date.now() - 10000 }, // Past
                queue_name: null
            })
        };

        const wrapped = test.wrap(myFunctions.expireReadyOrders);
        await wrapped({});

        expect(__mocks.mockUpdate).toHaveBeenCalledWith(docRef, expect.objectContaining({
            token_status: 'discarded'
        }));
    });

    it('should NOT transition token if deadline is in the future', async () => {
        const tokenId = 'token2';
        const docRef = { id: tokenId, parent: { parent: { id: 'order2' } } };
        __mocks.state.mockExpiredDocs = [{ ref: docRef, id: tokenId }];
        
        __mocks.state.mockTokenSnaps[tokenId] = {
            data: () => ({
                token_status: 'ready_for_pickup',
                collection_deadline: { toMillis: () => Date.now() + 10000 } // Future
            })
        };

        const wrapped = test.wrap(myFunctions.expireReadyOrders);
        await wrapped({});

        expect(__mocks.mockUpdate).not.toHaveBeenCalled();
    });

    it('should NOT transition token if status already changed (e.g. delivered)', async () => {
        const tokenId = 'token3';
        const docRef = { id: tokenId, parent: { parent: { id: 'order3' } } };
        __mocks.state.mockExpiredDocs = [{ ref: docRef, id: tokenId }];
        
        __mocks.state.mockTokenSnaps[tokenId] = {
            data: () => ({
                token_status: 'delivered', // Concurrency change
                collection_deadline: { toMillis: () => Date.now() - 10000 }
            })
        };

        const wrapped = test.wrap(myFunctions.expireReadyOrders);
        await wrapped({});

        expect(__mocks.mockUpdate).not.toHaveBeenCalled();
    });

    it('should clean up stale queue entries if they exist', async () => {
        const tokenId = 'token4';
        const docRef = { id: tokenId, parent: { parent: { id: 'order4' } } };
        __mocks.state.mockExpiredDocs = [{ ref: docRef, id: tokenId }];
        
        __mocks.state.mockTokenSnaps[tokenId] = {
            data: () => ({
                token_status: 'ready_for_pickup',
                collection_deadline: { toMillis: () => Date.now() - 10000 },
                queue_name: 'Dosa',
                prep_units_in_queue: 1,
                token_number: 12
            })
        };

        __mocks.state.mockQueueSnap = {
            exists: true,
            data: () => ({
                queue: [{ token_id: tokenId }]
            })
        };

        const wrapped = test.wrap(myFunctions.expireReadyOrders);
        await wrapped({});

        expect(__mocks.mockUpdate).toHaveBeenCalledTimes(2); // One for token, one for queue
        expect(__mocks.mockArrayRemove).toHaveBeenCalled();
        expect(__mocks.mockIncrement).toHaveBeenCalledWith(-1);
    });
});
