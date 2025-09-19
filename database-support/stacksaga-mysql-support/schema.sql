create table es_on_going_transaction
(
    transaction_uid                       varchar(255)                     not null,
    service_name                          varchar(255)                     null,
    transaction_token                     bigint                           null,
    last_exposed_time                     timestamp(6)                     null comment 'What is the last time the transaction sent to re-invoke.                     avery time the retry_exposed_count is updated, this will be updated.',
    retry_execution_retention_ending_time timestamp(6)                     null,
    last_retry_main_session               varchar(36)                      null comment 'The session id of the main schedule.',
    region                                varchar(255)                     null,
    zone                                  varchar(255)                     null,
    crashed_expose_datetime               timestamp(6)                     null comment 'When the transaction is exposed to restoring as invokable transaction. [crashed_expose_datetime + current time UTC]',
    target_retry_end_time                 timestamp(6)                     null comment 'What is the last time the transaction can be retied. after expiring the time the transaction will be freeze. it can be change from the admin dashboard.',
    crashed_expose_interval               bigint                           not null comment 'the value is in seconds',
    retry_execution_retention_interval    bigint                           null,
    impl_type                             enum ('ASYNC_IMPL', 'SYNC_IMPL') not null comment 'implementation of the saga like async, snyc ..',
    constraint transaction_uid
        unique (transaction_uid)
);

create index es_on_going_transaction_ending_time_index
    on es_on_going_transaction (retry_execution_retention_ending_time);

create index es_on_going_transaction_last_exposed_time_index
    on es_on_going_transaction (last_exposed_time);

create index es_on_going_transaction_last_retry_main_session_index
    on es_on_going_transaction (last_retry_main_session);

create index es_on_going_transaction_region_index
    on es_on_going_transaction (region);

create index es_on_going_transaction_region_index_region
    on es_on_going_transaction (region);

create index es_on_going_transaction_service_name_index
    on es_on_going_transaction (service_name);

create index es_on_going_transaction_target_retry_end_time_index
    on es_on_going_transaction (target_retry_end_time);

create index es_on_going_transaction_transaction_token_index
    on es_on_going_transaction (transaction_token);

create table es_terminated_transaction
(
    id                           bigint auto_increment
        primary key,
    transaction_uid              varchar(100) not null,
    transaction_initialized_time datetime     not null,
    terminated_time              datetime     not null,
    exception_class_name         varchar(255) null,
    exception_message            text         null,
    exception_log                longblob     null
);

create table es_transaction
(
    transaction_uid                             varchar(255)                                                                               not null,
    db_init_datetime                            timestamp(6)                                                                               not null,
    init_aggregator_version                     varchar(80)                                                                                not null,
    aggregator_name                             varchar(255)                                                                               not null,
    recent_tryout_transaction_execution_uid     varchar(36)                                                                                null comment 'most recent tryout id. it should be updated every execution except **temp-revert main.',
    start_datetime                              timestamp(6)                                                                               not null,
    last_action_datetime                        timestamp(6)                                                                               not null,
    has_process_error                           int                                                                                        not null comment 'if the total process has a process exception (to forward). the maximum number will be 1.                     because, one transaction can have only one unexpected exception. (connection exceptions is not added here) [this is not related to the middleware errors]',
    process_error_tryout_uid                    varchar(36)                                                                                null comment 'if there is a process error the execution tryout id should be added here to direct join',
    has_revert_error                            int                                                                                        not null comment 'if the transaction was failed due to a revert non-retryable exception. this is no related to the middleware errors.',
    revert_error_tryout_uid                     varchar(36)                                                                                null comment 'if there is a revert error the execution tryout id should be added here to direct join',
    has_middleware_termination_error            int                                                                                        not null comment 'if got an any converting error or database error (without the connection problem) this value will be updated.                     [this is related to the middleware error]                     if this value is updated, the middleware_termination_error_log should be updated as well at the same time.',
    middleware_termination_error_log            longblob                                                                                   null comment 'if the transaction has been terminated, the error log will be stored here.',
    release_version                             varchar(255)                                                                               not null comment 'the release version of the service when the transaction was executed. [service-name:service-version] ',
    current_tx_status                           enum ('PROCESSING', 'PROCESS_COMPLETED', 'REVERTING', 'REVERT_FAILED', 'REVERT_COMPLETED') not null comment 'This the final action was doing in last.',
    target_retry_end_time                       timestamp(6)                                                                               null comment 'What is the last time the transaction can be retied. after expiring the time the transaction will be freeze. it can be change from the admin dashboard.',
    instance_uid                                varchar(255)                                                                               not null,
    zone_id                                     varchar(50)                                                                                not null comment 'the zone of the transaction that was initialized.',
    region                                      varchar(255)                                                                               null comment 'the region of the transaction that was initialized.',
    base_service                                varchar(255)                                                                               not null comment 'the target service of the entire transaction. (base service)',
    current_retryable_error_related_service_uid varchar(255)                                                                               null,
    tx_condition                                enum ('LIVE', 'RETRY_TIME_EXCEEDED') default 'LIVE'                                        not null comment 'what is the overall condition of the transaction. if tge transaction is disabled due to the transaction retry is exceeded,the value will be updated as RETRY_TIME_EXCEEDED.',
    saga_mode                                   varchar(255)                                                                               not null,
    constraint `PRIMARY`
        primary key (transaction_uid),
    constraint transaction_uid
        unique (transaction_uid)
);

create table es_transaction_execution_tryout
(
    transaction_uid                  varchar(255)                                                                            not null,
    transaction_execution_tryout_uid varchar(36)                                                                             not null,
    db_init_datetime                 timestamp(6)                                                                            not null comment 'the real time the chunk file was saved.',
    next_executor_name               varchar(255)                                                                            null,
    event_name                       varchar(255)                                                                            not null,
    target_service_name              varchar(255)                                                                            not null,
    executor_full_name               varchar(255)                                                                            not null,
    executor_name                    varchar(255)                                                                            not null,
    parent_executor_name             varchar(255)                                                                            null,
    executor_type                    enum ('COMMAND', 'QUERY', 'INIT', 'REVERT_BEFORE', 'REVERT_AFTER', 'UNKNOWN')           not null,
    execution_mode                   enum ('DO_PROCESS', 'DO_REVERT_MAIN', 'DO_REVERT_BEFORE', 'DO_REVERT_AFTER', 'UNKNOWN') not null,
    is_revert_completed              bit default b'0'                                                                        not null,
    start_datetime                   timestamp(6)                                                                            null,
    end_datetime                     timestamp(6)                                                                            null,
    error_log                        longblob                                                                                null,
    error_binaries                   longblob                                                                                null,
    in_data                          json                                                                                    not null,
    out_data                         json                                                                                    null,
    flat_order                       int                                                                                     not null,
    status                           enum ('SUCCESS', 'FAILED', 'FAILED_WITH_NETWORK_EXCEPTION', 'TEMP', 'NOT_YET')          not null,
    row_type                         enum ('PRIMARY', 'REVERT')                                                              not null comment 'if the execution is a primary or revert one.',
    real_order                       bigint                                                                                  null,
    constraint `PRIMARY`
        primary key (transaction_uid, transaction_execution_tryout_uid)
);

create table es_tx_tryout_update_log
(
    tx_tryout_uid varchar(36) not null,
    constraint `PRIMARY`
        primary key (tx_tryout_uid),
    constraint tx_tryout_uid
        unique (tx_tryout_uid)
);
