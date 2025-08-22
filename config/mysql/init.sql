-- config/mysql/init.sql
-- This script runs when MySQL container starts up

-- Create all required databases
CREATE DATABASE IF NOT EXISTS heimdall_production;
CREATE DATABASE IF NOT EXISTS heimdall_production_cache;
CREATE DATABASE IF NOT EXISTS heimdall_production_queue;
CREATE DATABASE IF NOT EXISTS heimdall_production_cable;
CREATE DATABASE IF NOT EXISTS freeradius;

-- The MYSQL_USER and MYSQL_PASSWORD environment variables are automatically 
-- used by the MySQL Docker image to create the user defined in docker-compose/kamal config
-- So we just need to grant additional permissions to the auto-created user

-- Grant permissions on all heimdall databases to the auto-created user
GRANT ALL PRIVILEGES ON heimdall_production.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_cache.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_queue.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_cable.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON freeradius.* TO 'heimdall'@'%';

FLUSH PRIVILEGES;

-- Create FreeRADIUS tables
USE freeradius;

-- Table structure for 'nas' (Network Access Servers)
-- This table is already created by Rails migrations, but we need to ensure it exists
-- The Heimdall 'nas' table serves as the FreeRADIUS clients table

-- Table structure for 'radacct' (RADIUS Accounting)
CREATE TABLE IF NOT EXISTS radacct (
  radacctid bigint(21) NOT NULL auto_increment,
  acctsessionid varchar(64) NOT NULL default '',
  acctuniqueid varchar(32) NOT NULL default '',
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  realm varchar(64) default '',
  nasipaddress varchar(15) NOT NULL default '',
  nasportid varchar(15) default NULL,
  nasporttype varchar(32) default NULL,
  acctstarttime datetime NULL default NULL,
  acctstoptime datetime NULL default NULL,
  acctsessiontime int(12) unsigned default NULL,
  acctauthentic varchar(32) default NULL,
  connectinfo_start varchar(50) default NULL,
  connectinfo_stop varchar(50) default NULL,
  acctinputoctets bigint(20) unsigned default NULL,
  acctoutputoctets bigint(20) unsigned default NULL,
  calledstationid varchar(50) NOT NULL default '',
  callingstationid varchar(50) NOT NULL default '',
  acctterminatecause varchar(32) NOT NULL default '',
  servicetype varchar(32) default NULL,
  framedprotocol varchar(32) default NULL,
  framedipaddress varchar(15) NOT NULL default '',
  acctstartdelay int(12) unsigned default NULL,
  acctstopdelay int(12) unsigned default NULL,
  xascendsessionsvrkey varchar(10) default NULL,
  PRIMARY KEY (radacctid),
  UNIQUE KEY acctuniqueid (acctuniqueid),
  KEY username (username),
  KEY framedipaddress (framedipaddress),
  KEY acctsessionid (acctsessionid),
  KEY acctsessiontime (acctsessiontime),
  KEY acctstarttime (acctstarttime),
  KEY acctinterval (acctstarttime, acctstoptime),
  KEY acctstoptime (acctstoptime),
  KEY nasipaddress (nasipaddress)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radcheck' (RADIUS User Check Attributes)
CREATE TABLE IF NOT EXISTS radcheck (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL DEFAULT '==',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radreply' (RADIUS User Reply Attributes)
CREATE TABLE IF NOT EXISTS radreply (
  id int(11) unsigned NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL DEFAULT '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radgroupcheck' (RADIUS Group Check Attributes)
CREATE TABLE IF NOT EXISTS radgroupcheck (
  id int(11) unsigned NOT NULL auto_increment,
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL DEFAULT '==',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY groupname (groupname(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radgroupreply' (RADIUS Group Reply Attributes)
CREATE TABLE IF NOT EXISTS radgroupreply (
  id int(11) unsigned NOT NULL auto_increment,
  groupname varchar(64) NOT NULL default '',
  attribute varchar(64) NOT NULL default '',
  op char(2) NOT NULL DEFAULT '=',
  value varchar(253) NOT NULL default '',
  PRIMARY KEY (id),
  KEY groupname (groupname(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radusergroup' (RADIUS User to Group Mapping)
CREATE TABLE IF NOT EXISTS radusergroup (
  username varchar(64) NOT NULL default '',
  groupname varchar(64) NOT NULL default '',
  priority int(11) NOT NULL default '1',
  KEY username (username(32))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Table structure for 'radpostauth' (RADIUS Post-Authentication Logging)
CREATE TABLE IF NOT EXISTS radpostauth (
  id int(11) NOT NULL auto_increment,
  username varchar(64) NOT NULL default '',
  pass varchar(64) NOT NULL default '',
  reply varchar(32) NOT NULL default '',
  authdate timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY username (username),
  KEY authdate (authdate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
