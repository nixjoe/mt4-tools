/*
Created     16.01.2017
Project     XTrade
Model       Main model
Author      Peter Walther
Database    SQLite3
*/


.open --new "XTrade.db"


-- drop all database objects
.bail on
pragma writable_schema = 1;
delete from sqlite_master;
pragma writable_schema = 0;
vacuum;
pragma foreign_keys = on;


-- InstrumentTypes
create table enum_instrumenttype (
    type text not null collate nocase,
    primary key (type)
);
insert into enum_instrumenttype (type) values
   ('Forex'    ),
   ('Metals'   ),
   ('Synthetic');


-- OrderTypes
create table enum_ordertype (
    type text not null collate nocase,
    primary key (type)
);
insert into enum_ordertype (type) values
   ('Buy' ),
   ('Sell');


-- TickModels
create table enum_tickmodel (
    type text not null collate nocase,
    primary key (type)
);
insert into enum_tickmodel (type) values
   ('EveryTick'    ),
   ('ControlPoints'),
   ('BarOpen'      );


-- TradeDirections
create table enum_tradedirection (
    type text not null collate nocase,
    primary key (type)
);
insert into enum_tradedirection (type) values
   ('Long' ),
   ('Short'),
   ('Both' );


-- Instruments
create table t_instrument (
   id                 integer        not null,
   created            text[datetime] not null default (datetime('now')),   -- GMT
   modified           text[datetime],                                      -- GMT
   type               text[enum]     not null collate nocase,              -- Forex|Metals|Synthetic
   symbol             text(11)       not null collate nocase,
   description        text(63)       not null collate nocase,
   digits             integer        not null,
   historystart_ticks text[datetime],                                      -- FXT
   historystart_m1    text[datetime],                                      -- FXT
   historystart_d1    text[datetime],                                      -- FXT
   primary key (id),
   constraint fk_instrument_type foreign key (type) references enum_instrumenttype(type) on delete restrict on update cascade,
   constraint u_symbol           unique (symbol)
);
create index i_instrument_type on t_instrument(type);

create trigger tr_instrument_after_update after update on t_instrument
when (new.modified = old.modified || new.modified is null)
begin
   update t_instrument set modified = datetime('now') where id = new.id;
end;


-- Tests
create table t_test (
   id              integer        not null,
   created         text[datetime] not null default (datetime('now')),      -- GMT
   modified        text[datetime],                                         -- GMT
   strategy        text(255)      not null collate nocase,                 -- tested strategy
   reportingid     integer        not null,                                -- the test's reporting id
   reportingsymbol text(11)       not null collate nocase,                 -- the test's reporting symbol
   symbol          text(11)       not null collate nocase,                 -- tested symbol
   timeframe       integer        not null,                                -- tested timeframe
   starttime       text[datetime] not null,                                -- FXT
   endtime         text[datetime] not null,                                -- FXT
   tickmodel       text[enum]     not null collate nocase,                 -- EveryTick|ControlPoints|BarOpen
   spread          float(2,1)     not null,                                -- in pips
   bars            integer        not null,                                -- number of tested bars
   ticks           integer        not null,                                -- number of tested ticks
   tradedirections text[enum]     not null collate nocase,                 -- Long|Short|Both
   visualmode      integer[bool]  not null,
   duration        integer        not null,                                -- test duration in seconds
   primary key (id),
   constraint fk_test_tickmodel       foreign key (tickmodel)       references enum_tickmodel(type)      on delete restrict on update cascade,
   constraint fk_test_tradedirections foreign key (tradedirections) references enum_tradedirection(type) on delete restrict on update cascade,
   constraint u_reportingsymbol       unique (reportingsymbol),
   constraint u_strategy_reportingid  unique (strategy, reportingid)
);
create index i_test_strategy        on t_test(strategy);
create index i_test_symbol          on t_test(symbol);
create index i_test_tickmodel       on t_test(tickmodel);
create index i_test_tradedirections on t_test(tradedirections);

create trigger tr_test_after_update after update on t_test
when (new.modified = old.modified || new.modified is null)
begin
   update t_test set modified = datetime('now') where id = new.id;
end;


-- StrategyParameters
create table t_strategyparameter (
   id      integer   not null,
   name    text(32)  not null collate nocase,
   value   text(255) not null collate nocase,
   test_id integer   not null,
   primary key (id),
   constraint fk_strategyparameter_test foreign key (test_id) references t_test(id) on delete cascade on update cascade,
   constraint u_test_name               unique (test_id, name)
);


-- Orders
create table t_order (
   id            integer        not null,
   created       text[datetime] not null default (datetime('now')),        -- GMT
   modified      text[datetime],                                           -- GMT
   ticket        integer        not null,
   type          text[enum]     not null collate nocase,                   -- Buy|Sell
   lots          float(10,2)    not null,
   symbol        text(11)       not null collate nocase,
   openprice     float(10,5)    not null,
   opentime      text[datetime] not null,                                  -- FXT
   stoploss      float(10,5),
   takeprofit    float(10,5),
   closeprice    float(10,5)    not null,
   closetime     text[datetime] not null,                                  -- FXT
   commission    float(10,2)    not null,
   swap          float(10,2)    not null,
   profit        float(10,2)    not null,                                  -- gross profit
   magicnumber   integer,
   comment       text(27)                collate nocase,
   test_id       integer        not null,
   primary key (id),
   constraint fk_order_type foreign key (type)    references enum_ordertype(type) on delete restrict on update cascade,
   constraint fk_order_test foreign key (test_id) references t_test(id)           on delete restrict on update cascade,
   constraint u_test_ticket unique (test_id, ticket)
);
create index i_order_type on t_order(type);

create trigger tr_order_after_update after update on t_order
when (new.modified = old.modified || new.modified is null)
begin
   update t_order set modified = datetime('now') where id = new.id;
end;


-- Test statistics
create table t_statistic (
   id           integer     not null,
   trades       integer     not null,
   trades_day   float(10,1) not null,                                      -- trades per day
   duration_min integer     not null,                                      -- minimum trade duration in seconds
   duration_avg integer     not null,                                      -- average trade duration in seconds
   duration_max integer     not null,                                      -- maximum trade duration in seconds
   pips_min     float(10,1) not null,                                      -- minimum trade profit in pips
   pips_avg     float(10,1) not null,                                      -- average trade profit in pips
   pips_max     float(10,1) not null,                                      -- maximum trade profit in pips
   pips         float(10,1) not null,                                      -- full test profit in pips
   profit       float(10,2) not null,                                      -- test gross profit in currency
   commission   float(10,2) not null,                                      -- test commission
   swap         float(10,2) not null,                                      -- test swap
   test_id      integer     not null,
   primary key (id),
   constraint fk_statistic_test foreign key (test_id) references t_test (id) on delete cascade on update cascade,
   constraint u_test            unique (test_id)
);


-- check schema
.lint fkey-indexes


-- seed the database
.read "xtrade_seed.sql"
