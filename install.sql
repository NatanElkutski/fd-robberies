-- FD-robberies by FIVE DEV - Database Installation
-- Compatible with oxmysql / QBCore

CREATE TABLE IF NOT EXISTS `fd_robbery_progress` (
  `citizenid` VARCHAR(64) NOT NULL,
  `xp` INT NOT NULL DEFAULT 0,
  `completed` INT NOT NULL DEFAULT 0,
  `criminal_name` VARCHAR(24) NULL,
  `criminal_avatar` VARCHAR(32) NOT NULL DEFAULT 'face01',
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
