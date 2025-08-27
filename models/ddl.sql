-- 企业表
CREATE TABLE orgs (
    orgid VARCHAR(32) PRIMARY KEY COMMENT '企业ID（主键）',
    name VARCHAR(255) NOT NULL COMMENT '企业名称',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) COMMENT='企业表';

-- 流程定义表
CREATE TABLE flow_definitions (
    id VARCHAR(32) PRIMARY KEY COMMENT '流程定义ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    code VARCHAR(100) NOT NULL COMMENT '流程编码（企业内唯一）',
    name VARCHAR(255) NOT NULL COMMENT '流程名称',
    version INT NOT NULL DEFAULT 1 COMMENT '流程版本',
    description TEXT COMMENT '流程描述',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '流程状态：1=启用 0=停用',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE KEY uk_org_code_version (orgid, code, version)
) COMMENT='流程定义表';

-- 流程节点定义表（增加子流程字段）
CREATE TABLE flow_nodes (
    id VARCHAR(32) PRIMARY KEY COMMENT '节点ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_definition_id VARCHAR(32) NOT NULL COMMENT '所属流程定义ID',
    node_key VARCHAR(100) NOT NULL COMMENT '节点唯一标识（流程内唯一）',
    name VARCHAR(255) NOT NULL COMMENT '节点名称',
    type ENUM('start','task','gateway','subflow','end') NOT NULL COMMENT '节点类型',
    role_id VARCHAR(32) COMMENT '节点分配角色ID',
    assignment_type VARCHAR(50) COMMENT '任务分配类型（轮询/抢占/自动）',
    properties JSON COMMENT '节点属性（JSON格式，自定义扩展）',
    subflow_definition_id VARCHAR(32) COMMENT '子流程定义ID（type=subflow时使用）',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    UNIQUE(flow_definition_id, node_key),
    FOREIGN KEY(flow_definition_id) REFERENCES flow_definitions(id) ON DELETE CASCADE,
    FOREIGN KEY(subflow_definition_id) REFERENCES flow_definitions(id)
) COMMENT='流程节点定义表';

-- 节点转移表
CREATE TABLE flow_transitions (
    id VARCHAR(32) PRIMARY KEY COMMENT '节点转移ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_definition_id VARCHAR(32) NOT NULL COMMENT '所属流程定义ID',
    source_node_id VARCHAR(32) NOT NULL COMMENT '起始节点ID',
    target_node_id VARCHAR(32) NOT NULL COMMENT '目标节点ID',
    condition_expr VARCHAR(1000) COMMENT '转移条件表达式',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY(source_node_id) REFERENCES flow_nodes(id),
    FOREIGN KEY(target_node_id) REFERENCES flow_nodes(id)
) COMMENT='流程节点转移表';

-- 节点表单表
CREATE TABLE flow_node_forms (
    id VARCHAR(32) PRIMARY KEY COMMENT '节点表单ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_node_id VARCHAR(32) NOT NULL COMMENT '节点ID',
    schema JSON NOT NULL COMMENT '表单结构定义（JSON/JIO）',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY(flow_node_id) REFERENCES flow_nodes(id)
) COMMENT='节点表单定义表';

-- 流程实例表
CREATE TABLE flow_instances (
    id VARCHAR(32) PRIMARY KEY COMMENT '流程实例ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_definition_id VARCHAR(32) NOT NULL COMMENT '流程定义ID',
    version INT NOT NULL COMMENT '流程版本',
    status ENUM('running','completed','terminated') DEFAULT 'running' COMMENT '实例状态',
    context JSON COMMENT '运行时上下文数据',
    created_by VARCHAR(32) NOT NULL COMMENT '发起人用户ID',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY(flow_definition_id) REFERENCES flow_definitions(id)
) COMMENT='流程实例表';

-- 流程实例节点表（增加 parent_instance_node_id 支持子流程嵌套）
CREATE TABLE flow_instance_nodes (
    id VARCHAR(32) PRIMARY KEY COMMENT '流程实例节点ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_instance_id VARCHAR(32) NOT NULL COMMENT '流程实例ID',
    flow_node_id VARCHAR(32) NOT NULL COMMENT '流程节点ID',
    parent_instance_node_id VARCHAR(32) COMMENT '父节点实例ID（子流程时使用）',
    status ENUM('pending','in_progress','completed','skipped') DEFAULT 'pending' COMMENT '节点实例状态',
    assigned_to VARCHAR(32) COMMENT '指派用户ID（当前）',
    form_data JSON COMMENT '填写的表单数据',
    started_at TIMESTAMP COMMENT '节点开始时间',
    completed_at TIMESTAMP COMMENT '节点完成时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY(flow_instance_id) REFERENCES flow_instances(id),
    FOREIGN KEY(flow_node_id) REFERENCES flow_nodes(id),
    FOREIGN KEY(parent_instance_node_id) REFERENCES flow_instance_nodes(id)
) COMMENT='流程实例节点表';

-- 节点任务表（人工任务）
CREATE TABLE flow_tasks (
    id VARCHAR(32) PRIMARY KEY COMMENT '任务ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    instance_node_id VARCHAR(32) NOT NULL COMMENT '流程实例节点ID',
    assignee_id VARCHAR(32) COMMENT '指派用户ID（原始）',
    candidate_role VARCHAR(128) COMMENT '候选角色',
    status ENUM('pending','claimed','completed','failed') DEFAULT 'pending' COMMENT '任务状态',
    input JSON COMMENT '任务输入数据',
    output JSON COMMENT '任务输出数据',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY(instance_node_id) REFERENCES flow_instance_nodes(id)
) COMMENT='节点任务表';

-- 用户代理表（请假/任务委托）
CREATE TABLE user_delegations (
    id VARCHAR(32) PRIMARY KEY COMMENT '委托ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    user_id VARCHAR(32) NOT NULL COMMENT '原始任务用户ID',
    delegate_id VARCHAR(32) NOT NULL COMMENT '代理用户ID',
    start_time DATETIME NOT NULL COMMENT '生效开始时间',
    end_time DATETIME NOT NULL COMMENT '生效结束时间',
    status TINYINT DEFAULT 1 COMMENT '状态：1=生效 0=停用',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间'
) COMMENT='用户代理表';

-- 流程日志表
CREATE TABLE flow_logs (
    id VARCHAR(32) PRIMARY KEY COMMENT '日志ID',
    orgid VARCHAR(32) NOT NULL COMMENT '企业ID',
    flow_instance_id VARCHAR(32) NOT NULL COMMENT '流程实例ID',
    flow_node_id VARCHAR(32) COMMENT '节点ID（可为空）',
    parent_instance_node_id VARCHAR(32) COMMENT '父节点实例ID（子流程时使用）',
    action VARCHAR(100) NOT NULL COMMENT '操作动作（start, complete, assign, transition, terminate）',
    operator_id VARCHAR(32) COMMENT '操作人用户ID',
    original_assignee_id VARCHAR(32) COMMENT '原始任务指派人（代理场景使用）',
    message TEXT COMMENT '日志内容',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    FOREIGN KEY(flow_instance_id) REFERENCES flow_instances(id),
    FOREIGN KEY(flow_node_id) REFERENCES flow_nodes(id),
    FOREIGN KEY(parent_instance_node_id) REFERENCES flow_instance_nodes(id)
) COMMENT='流程日志表';

