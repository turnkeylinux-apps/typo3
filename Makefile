COMMON_CONF = apache-credit

CREDIT_LOCATION = ~ "^/(?!(.*typo3))"
PHP_UPLOAD_MAX_FILESIZE = 10M
PHP_MEMORY_LIMIT = 128M
PHP_MAX_EXECUTION_TIME = 240
HP_MAX_INPUT_VARS = 1500

include $(FAB_PATH)/common/mk/turnkey/composer.mk
include $(FAB_PATH)/common/mk/turnkey/lamp.mk
include $(FAB_PATH)/common/mk/turnkey.mk
