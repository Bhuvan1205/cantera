"""
Structured Logging and Audit Logging Configuration.
"""

import json
import logging
import sys

# Configure standard logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    stream=sys.stdout,
)

logger = logging.getLogger("canteen.api")
audit_logger = logging.getLogger("canteen.audit")


def setup_logging() -> None:
    """Explicitly initializes and confirms logging configuration."""
    logger.info("Application logging and audit subsystem initialized.")


def log_audit(action: str, actor_uid: str, target: str, details: dict | None = None) -> None:
    """
    Emits a structured JSON audit log entry to standard output.
    
    Fields:
        action: Identifier of the administrative operation (e.g., 'INVENTORY_STOCK_UPDATE')
        actor_uid: UID of the authenticated admin executing the action
        target: Target resource identifier (e.g., 'Inventory/item_123', 'Users/user_456')
        details: Additional context parameters (e.g., old/new stock, adjustment amount, reason)
    """
    record = {
        "audit_event": action,
        "actor_uid": actor_uid,
        "target_resource": target,
        "details": details or {},
    }
    audit_logger.info(f"AUDIT_RECORD: {json.dumps(record, default=str)}")
