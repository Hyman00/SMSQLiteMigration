A database upgrade tool that based on FMDB

## How does it work
According to the different reference database and local database, upgrade the differences

## Support
1，Add new field（the new field of constraint only support: PK, DefaultValue, NOT NULL）

2，Add new table, Delete table, Rename table

> Rename table must be in accordance with the following format to rename the table name：oldTableName_to_newTableName
> 
>Migration, when recognition to the format of the table name, will extract the oldTableName and newTableName, and then judge whether the oldTableName exists in oldDB, if any, is renamed as newTableName;Otherwise, the oldTableName_to_newTableName will be treated as an ordinary table name
> 

3，Add new index, Delete index

4，Does not support this case: foreign key constraints exist in the database

## How to use
First, create an empty DB in your project, which holds the latest table structure; that is, each time you upgrade the database, simply modify the corresponding table in the DB

Use the following statement to determine if an upgrade is required:
```ObjC
if ([SMSQLiteMigration versionForDB:self.db] < kCurrentVersion) {
  // upgrade .....
}
```
When the need to upgrade DB, execute the following statement:
```ObjC
NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB" ofType:@"sqlite"];
FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
if ([referDB open]) {
  BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:kCurrentVersion];
  
  // ....
}
```
