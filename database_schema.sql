-- 通用SQL建库脚本（适用于 SQLite / PostgreSQL / MySQL 的基础语法）
-- 用途：初始化一个“企业发布项目、个人接单”的示例数据库：组织、工作者、项目、支付
-- 使用方法：
--   SQLite:   sqlite3 app.db < database_schema.sql
--   Postgres: psql -h HOST -U USER -d DB -f database_schema.sql
--   MySQL:    mysql -h HOST -u USER -p DB < database_schema.sql

-- 注意：
-- - 若目标数据库已存在同名表，可先手动 DROP，或将下方 DROP 语句取消注释。
-- - 时间戳列统一使用 UTC；不同数据库的默认值支持差异较大，以下选择尽量通用的写法。
-- - 如需严格区分数据库方言，请按需改造数据类型与默认值表达式。

-- 可选：先删除旧表（按需取消注释，注意外键顺序）
-- DROP TABLE IF EXISTS Payment_Table;
-- DROP TABLE IF EXISTS Project_Table;
-- DROP TABLE IF EXISTS Worker_Table;
-- DROP TABLE IF EXISTS Organization_Table;

-- 开始事务（SQLite 会隐式处理；Postgres/MySQL 建议显式事务）
-- 对不支持的引擎，此语句可忽略
BEGIN;

-- 组织表
CREATE TABLE IF NOT EXISTS Organization_Table (
  id                 INTEGER PRIMARY KEY,
  name               VARCHAR(255) NOT NULL,
  contact_email      VARCHAR(255) NOT NULL,
  contact_phone      VARCHAR(50),
  website_url        VARCHAR(255),
  is_verified        BOOLEAN NOT NULL DEFAULT 0,

  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_org_name_unique ON Organization_Table(name);
CREATE UNIQUE INDEX IF NOT EXISTS idx_org_email_unique ON Organization_Table(contact_email);

-- 工作者表
CREATE TABLE IF NOT EXISTS Worker_Table (
  id                 INTEGER PRIMARY KEY,
  full_name          VARCHAR(255) NOT NULL,
  email              VARCHAR(255) NOT NULL,
  phone              VARCHAR(50),
  skills             TEXT, -- 逗号分隔或 JSON（按需调整）
  hourly_rate_cents  INTEGER CHECK (hourly_rate_cents >= 0),
  is_active          BOOLEAN NOT NULL DEFAULT 1,

  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_worker_email_unique ON Worker_Table(email);
CREATE INDEX IF NOT EXISTS idx_worker_active ON Worker_Table(is_active);

-- 项目表
CREATE TABLE IF NOT EXISTS Project_Table (
  id                 INTEGER PRIMARY KEY,
  organization_id    INTEGER NOT NULL,
  title              VARCHAR(255) NOT NULL,
  description        TEXT,
  required_skills    TEXT,
  budget_cents       INTEGER CHECK (budget_cents >= 0),
  currency           VARCHAR(10) NOT NULL DEFAULT 'USD',
  status             VARCHAR(32) NOT NULL DEFAULT 'open', -- open/assigned/in_progress/completed/cancelled
  assigned_worker_id INTEGER, -- 可为空，表示尚未指派
  start_date         DATE,
  due_date           DATE,

  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (organization_id) REFERENCES Organization_Table(id),
  FOREIGN KEY (assigned_worker_id) REFERENCES Worker_Table(id)
);

CREATE INDEX IF NOT EXISTS idx_project_org ON Project_Table(organization_id);
CREATE INDEX IF NOT EXISTS idx_project_status ON Project_Table(status);
CREATE INDEX IF NOT EXISTS idx_project_assigned_worker ON Project_Table(assigned_worker_id);

-- 支付表
CREATE TABLE IF NOT EXISTS Payment_Table (
  id                 INTEGER PRIMARY KEY,
  project_id         INTEGER NOT NULL,
  worker_id          INTEGER NOT NULL,
  organization_id    INTEGER NOT NULL,
  amount_cents       INTEGER NOT NULL CHECK (amount_cents >= 0),
  currency           VARCHAR(10) NOT NULL DEFAULT 'USD',
  method             VARCHAR(32) NOT NULL DEFAULT 'transfer', -- transfer/card/wallet 等
  status             VARCHAR(32) NOT NULL DEFAULT 'pending', -- pending/paid/failed/refunded
  paid_at            TIMESTAMP,

  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (project_id) REFERENCES Project_Table(id),
  FOREIGN KEY (worker_id) REFERENCES Worker_Table(id),
  FOREIGN KEY (organization_id) REFERENCES Organization_Table(id)
);

CREATE INDEX IF NOT EXISTS idx_payment_project ON Payment_Table(project_id);
CREATE INDEX IF NOT EXISTS idx_payment_worker ON Payment_Table(worker_id);
CREATE INDEX IF NOT EXISTS idx_payment_org ON Payment_Table(organization_id);
CREATE INDEX IF NOT EXISTS idx_payment_status ON Payment_Table(status);

-- 示例数据：组织
INSERT INTO Organization_Table (id, name, contact_email, contact_phone, website_url, is_verified)
VALUES
  (1, 'Heimdallr Tech', 'hr@heimdallr.tech', '+1-555-1010', 'https://heimdallr.tech', 1),
  (2, 'Bifrost Studio', 'hello@bifrost.studio', '+1-555-2020', 'https://bifrost.studio', 1),
  (3, 'Valhalla Labs', 'ops@valhalla.labs', NULL, NULL, 0);

-- 示例数据：工作者
INSERT INTO Worker_Table (id, full_name, email, phone, skills, hourly_rate_cents, is_active)
VALUES
  (1, 'Alice Zhang', 'alice@example.com', '+1-555-3001', 'React,TypeScript,Node.js', 6000, 1),
  (2, 'Bob Li', 'bob@example.com', NULL, 'Python,Data Analysis,SQL', 5500, 1),
  (3, 'Carlos Wang', 'carlos@example.com', '+1-555-3003', 'UI/UX,Sketch,Figma', 5000, 1),
  (4, 'Diana Chen', 'diana@example.com', '+1-555-3004', 'DevOps,AWS,Docker', 8000, 1);

-- 示例数据：项目（部分已指派）
INSERT INTO Project_Table (
  id, organization_id, title, description, required_skills, budget_cents, currency, status, assigned_worker_id, start_date, due_date
) VALUES
  (101, 1, 'Landing Page Revamp', 'Redesign and implement marketing site', 'UI/UX,React,Figma', 120000, 'USD', 'in_progress', 3, '2025-08-01', '2025-08-20'),
  (102, 2, 'Data Pipeline MVP', 'Build ETL for sales data', 'Python,SQL,AWS', 200000, 'USD', 'open', NULL, NULL, '2025-09-15'),
  (103, 1, 'CI/CD Setup', 'Create CI/CD for monorepo', 'DevOps,AWS,Docker', 150000, 'USD', 'assigned', 4, '2025-08-05', '2025-08-25'),
  (104, 3, 'Dashboard Prototype', 'Interactive analytics dashboard', 'React,TypeScript,Node.js', 180000, 'USD', 'completed', 1, '2025-07-01', '2025-07-25');

-- 示例数据：支付（仅对已完成/已计费项目）
INSERT INTO Payment_Table (
  id, project_id, worker_id, organization_id, amount_cents, currency, method, status, paid_at
) VALUES
  (9001, 104, 1, 3, 180000, 'USD', 'transfer', 'paid', '2025-07-28 10:00:00'),
  (9002, 101, 3, 1, 60000, 'USD', 'card', 'pending', NULL);

COMMIT;


