import React, { useEffect } from 'react';

export default function Modal({ isOpen, onClose, title, children, maxWidth = 'max-w-xl' }) {
  useEffect(() => {
    function handleKeyDown(e) {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-md">
      <div
        className="fixed inset-0 bg-inverse-surface/60 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      />
      <div
        className={`relative w-full ${maxWidth} bg-surface-container-lowest rounded-2xl shadow-2xl overflow-hidden border border-outline-variant/30 z-10 max-h-[90vh] flex flex-col`}
        role="dialog"
        aria-modal="true"
      >
        <div className="px-lg py-md bg-surface-container-low border-b border-outline-variant/20 flex items-center justify-between">
          <h3 className="font-title-sm text-on-surface">{title}</h3>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-on-surface-variant hover:bg-surface-variant/40 hover:text-on-surface transition-colors"
          >
            <span className="material-symbols-outlined text-[20px]">close</span>
          </button>
        </div>
        <div className="p-lg overflow-y-auto flex-1">{children}</div>
      </div>
    </div>
  );
}
