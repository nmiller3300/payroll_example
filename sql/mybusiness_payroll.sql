CREATE TABLE IF NOT EXISTS `mybusiness_payroll_access` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `job_name` VARCHAR(50) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 3,
  `granted_by` VARCHAR(50) NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_citizen_job` (`citizenid`,`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_jobs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `job_label` VARCHAR(100) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_job_grades` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `grade_level` INT NOT NULL,
  `grade_name` VARCHAR(100) NULL,
  `payment` DECIMAL(10,2) NULL,
  `synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_job_grade` (`job_name`,`grade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_theme` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `payload` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_job_theme` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_settings` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `period_days` INT NOT NULL DEFAULT 14,
  `period_anchor` BIGINT NOT NULL,
  `login_domain` VARCHAR(120) NOT NULL DEFAULT 'business.org',
  `business_name_override` VARCHAR(120) NULL,
  `business_logo_url` VARCHAR(500) NULL,
  `hourly_rate` DECIMAL(10,2) NOT NULL DEFAULT 100.00,
  `updated_by` VARCHAR(50) NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_job_settings` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_shifts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `employee_name` VARCHAR(120) NOT NULL,
  `job_name` VARCHAR(50) NOT NULL,
  `clock_in_ts` BIGINT NOT NULL,
  `clock_out_ts` BIGINT NULL,
  `total_minutes` INT NULL,
  `approved` TINYINT(1) NOT NULL DEFAULT 0,
  `notes` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_shift_job_period` (`job_name`,`clock_in_ts`),
  KEY `idx_shift_open` (`citizenid`,`job_name`,`clock_out_ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_adjustment_requests` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `employee_name` VARCHAR(120) NOT NULL,
  `minutes_delta` INT NOT NULL,
  `reason` VARCHAR(255) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
  `reviewed_by` VARCHAR(50) NULL,
  `reviewed_name` VARCHAR(120) NULL,
  `reviewed_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_adj_job_status` (`job_name`,`status`),
  KEY `idx_adj_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mybusiness_payroll_audit_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(50) NOT NULL,
  `action_type` VARCHAR(80) NOT NULL,
  `actor_citizenid` VARCHAR(50) NULL,
  `actor_name` VARCHAR(120) NULL,
  `target_citizenid` VARCHAR(50) NULL,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_job_time` (`job_name`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
