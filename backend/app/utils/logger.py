"""
Logging configuration and setup
Centralized logging for the application
"""

import logging
import logging.handlers
import os
from datetime import datetime


def setup_logger(app):
    """
    Configure application logging
    
    Args:
        app: Flask application instance
    """
    
    # Create logs directory if it doesn't exist
    log_dir = app.config.get('LOG_DIR', './logs')
    os.makedirs(log_dir, exist_ok=True)
    
    # Get logging configuration
    log_file = app.config.get('LOG_FILE', os.path.join(log_dir, 'campushive.log'))
    log_level = app.config.get('LOG_LEVEL', 'INFO')
    max_bytes = app.config.get('LOG_MAX_BYTES', 10485760)
    backup_count = app.config.get('LOG_BACKUP_COUNT', 10)
    
    # Set up file handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=max_bytes,
        backupCount=backup_count
    )
    
    # Create formatter
    formatter = logging.Formatter(
        '[%(asctime)s] %(levelname)s in %(module)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    file_handler.setFormatter(formatter)
    
    # Set logging level
    file_handler.setLevel(getattr(logging, log_level))
    app.logger.addHandler(file_handler)
    app.logger.setLevel(getattr(logging, log_level))
    
    app.logger.info('=== CampusHive Backend Started ===')
    app.logger.info(f'Environment: {app.config.get("ENV")}')
    app.logger.info(f'Debug Mode: {app.debug}')


def get_logger(name):
    """
    Get logger instance
    
    Args:
        name (str): Logger name
        
    Returns:
        logging.Logger: Logger instance
    """
    return logging.getLogger(name)
