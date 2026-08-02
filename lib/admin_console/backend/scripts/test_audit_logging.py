"""
Unit Tests for Structured Application and Audit Logging.
"""

import io
import json
import logging
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.logging import log_audit, setup_logging


class TestAuditLogging(unittest.TestCase):
    def test_setup_logging(self):
        with self.assertLogs("canteen.api", level="INFO") as cm:
            setup_logging()
            self.assertTrue(any("Application logging and audit subsystem initialized" in msg for msg in cm.output))

    def test_log_audit_format(self):
        with self.assertLogs("canteen.audit", level="INFO") as cm:
            log_audit(
                action="INVENTORY_ITEM_UPDATE",
                actor_uid="test_admin_123",
                target="Menu/item_abc",
                details={"new_stock": 50, "new_price": 25.0},
            )
            self.assertEqual(len(cm.output), 1)
            raw_msg = cm.output[0]
            self.assertIn("AUDIT_RECORD:", raw_msg)

            json_str = raw_msg.split("AUDIT_RECORD: ")[1]
            data = json.loads(json_str)
            self.assertEqual(data["audit_event"], "INVENTORY_ITEM_UPDATE")
            self.assertEqual(data["actor_uid"], "test_admin_123")
            self.assertEqual(data["target_resource"], "Menu/item_abc")
            self.assertEqual(data["details"]["new_stock"], 50)
            self.assertEqual(data["details"]["new_price"], 25.0)

    def test_log_audit_wallet_refund(self):
        with self.assertLogs("canteen.audit", level="INFO") as cm:
            log_audit(
                action="WALLET_REFUND_APPROVED",
                actor_uid="admin_777",
                target="refund_requests/ref_999",
                details={"status": "approved", "reason": "Accidental double charge"},
            )
            self.assertEqual(len(cm.output), 1)
            raw_msg = cm.output[0]
            json_str = raw_msg.split("AUDIT_RECORD: ")[1]
            data = json.loads(json_str)
            self.assertEqual(data["audit_event"], "WALLET_REFUND_APPROVED")
            self.assertEqual(data["actor_uid"], "admin_777")
            self.assertEqual(data["target_resource"], "refund_requests/ref_999")
            self.assertEqual(data["details"]["reason"], "Accidental double charge")


if __name__ == "__main__":
    unittest.main()
