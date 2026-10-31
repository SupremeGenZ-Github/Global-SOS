import pg from 'pg';
import {migrate,seedDB} from './store.mjs';
if(!process.env.DATABASE_URL){console.error('DATABASE_URL is required for migrations.');process.exit(1);}
const pool=new pg.Pool({connectionString:process.env.DATABASE_URL,connectionTimeoutMillis:10000});
try{const c=await pool.connect();try{await migrate(c);await seedDB(c);console.log('Database prepared. Existing records preserved.');}finally{c.release();}}catch{console.error('Database preparation failed; check connection and TLS settings.');process.exitCode=1;}finally{await pool.end();}
