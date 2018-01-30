$databaseName = "AdventureWorksDW2014"
$serverName = "localhost"
$userNameShort = "username"
$ServerAConnectionString = 'Data Source='+$serverName+';Initial Catalog='+$databaseName+';User Id='+ $userNameShort +';Integrated Security = True'
$ServerAConnection = new-object system.data.SqlClient.SqlConnection($ServerAConnectionString);

$tabularModelName = "AdventureWorksTest"

$impersonationMode = "impersonateAccount"
$account = "DOMAIN\\USERNAME"
$password = "PASSWORD"

$tabularModelDeploymentLocation = "C:\Temp\TabularModels\"

$views = Invoke-Sqlcmd -Query "USE $databaseName; SELECT name, ROW_NUMBER() OVER(order by name) AS rownum FROM sys.views WHERE schema_id <> 1;"
$tableRowNum = $views.rownum
$tableRowNum = (($tableRowNum|Measure-Object -Maximum).Maximum) 
$tableRowNum = $tableRowNum[0]

$tabularModel = ''

$createOrReplaceStatement = "{
  ""createOrReplace"": {
    ""object"": {
      ""database"": ""$tabularModelName""
    },"
$databaseObjectStatement = """database"": {
      ""name"": ""$tabularModelName"",
      ""compatibilityLevel"": 1200,
      ""model"": {
        ""culture"": ""en-GB"",
        ""dataSources"": [
          {
            ""name"": ""SqlServer $databaseName"",
            ""connectionString"": ""Provider=SQLNCLI11;Data Source=$serverName;Initial Catalog=$databaseName;Integrated Security=SSPI;Persist Security Info=false"",
            ""impersonationMode"": ""$impersonationMode"",
            ""account"":""$account"",
            ""password"":""$password"",
            ""annotations"": [
              {
                ""name"": ""ConnectionEditUISource"",
                ""value"": ""SqlServer""
              }
            ]
          }
        ],"

$tableObject = """tables"": [
          "

$tabularModel += $createOrReplaceStatement
$tabularModel += $databaseObjectStatement
$tabularModel += $tableObject

$n = 1

foreach ($item in $views)
{
    $tableName = $item.name
    $ddl = Invoke-Sqlcmd -Query "USE $databaseName;
    
			SELECT CONCAT(Table_schema,'.', Table_Name) AS TableName, 
		            Column_Name AS ColumnName,
                    ROW_NUMBER() OVER(PARTITION BY Table_Name ORDER BY Column_Name) AS RowNum
            FROM information_schema.columns c
            INNER JOIN sys.objects o ON c.TABLE_NAME = o.name AND o.type = 'V' AND c.TABLE_SCHEMA <> 'dbo'
            WHERE Table_Name = '$tableName'	"


    $fullyqualifiedname = $ddl.TableName[1]
    
    $tableObjects = "
            {""name"": ""$tableName"",
            ""columns"": ["

    $tabularModel += $tableObjects
    $rowNumber = $ddl.RowNum
    
    $rowNum = (($rowNumber|Measure-Object -Maximum).Maximum) 
    $rowNum = $rowNum[0]
    

    $i = 1


    foreach ($column in $ddl.ColumnName){

    $dataTypeQuery = Invoke-Sqlcmd -Query "USE $databaseName;
        WITH CTE AS (
			SELECT CONCAT(Table_schema,'.', Table_Name) AS FullTableName, 
			Table_schema AS TableSchema, 
			Table_Name AS TableName,
					Column_Name AS ColumnName, 
					CONCAT(Data_Type, CASE WHEN CHARACTER_MAXIMUM_LENGTH IS NULL
									THEN ''
									ELSE CONCAT('(', character_maximum_Length,')')END) AS DataType
			FROM information_schema.columns c
			INNER JOIN sys.objects o ON c.TABLE_NAME = o.name AND o.type = 'V' AND c.TABLE_SCHEMA <> 'dbo'
			)

        SELECT	--FullTableName,
        		TableSchema, 
        		TableName, 
        		ColumnName, 
        		DataType,
        		CASE WHEN DataType like '%int%' THEN 'int64'
        			 WHEN DataType like '%char%' THEN 'string'
        			 WHEN DataType = 'bit' THEN 'boolean'
        			 WHEN DataType = 'date' THEN 'dateTime'
        			 WHEN DataType = 'datetime' THEN 'dateTime'
        			 WHEN DataType = 'money' THEN 'decimal'
        			 WHEN DataType = 'float' THEN 'double'
        			 WHEN DataType = 'real' THEN 'double'
        			 WHEN DataType = 'numeric' THEN 'decimal'
        			 WHEN DataType = 'decimal' THEN 'decimal'
        			 ELSE ''
        		END AS TabularDataType,
        		CASE WHEN DataType = 'int' THEN 'Integer'
        			 WHEN DataType = 'smallint' THEN 'SmallInt'
        			 WHEN DataType = 'tinyint' THEN 'UnsignedTinyInt'
        			 WHEN DataType like 'n%char%' THEN 'WChar'
        			 WHEN DataType like '%char%' THEN 'Char'
        			 WHEN DataType = 'bit' THEN 'Boolean'
        			 WHEN DataType = 'date' THEN 'DBDate'
        			 WHEN DataType = 'datetime' THEN 'DBTimeStamp'
        			 WHEN DataType = 'money' THEN 'Currency'
        			 WHEN DataType = 'float' THEN 'Double'
        			 WHEN DataType = 'real' THEN 'Single'
        			 WHEN DataType = 'numeric' THEN 'decimal'
        			 WHEN DataType = 'decimal' THEN 'decimal'
        			 ELSE ''
        		END AS SourceDataType  
        FROM CTE
        WHERE TableName = '$tableName' AND ColumnName = '$column'"

        $tabularDataType = $dataTypeQuery.TabularDataType
        $sourceDataType = $dataTypeQuery.SourceDataType
        
    # Needs source data type
    $columnObjects = "
            {
                ""name"": ""$column"",
                ""dataType"": ""$tabularDataType"",
                ""sourceColumn"": ""$column"",
                ""sourceProviderType"": ""$sourceDataType""
              }"

        # if statement to append a comma at the right place
        If ($i -lt $rowNum)
        {$columnObjects += ","}

        $i = $i + 1

    $tabularModel += $columnObjects

    }

    $tabularModel += "],
            ""partitions"": [
              {
                ""name"": ""$tableName"",
                ""dataView"": ""full"",
                ""source"": {
                  ""query"": "" SELECT $fullyqualifiedname.* FROM $fullyqualifiedname "",
                  ""dataSource"": ""SqlServer $databaseName""
                }
              }
            ]
            }"
    
    If ($n -lt $tableRowNum)
        {$tabularModel += ","}

        $n = $n + 1

 
    
}

$tabularModel += "]
                  }
                }
              }
            }"



$tabularModel | out-file "$tabularModelDeploymentLocation $tabularModelName.json"

$serverName = "localhost"
# Refresh options for database are: full clearValues calculate dataOnly automatic defragment
$refreshType = "automatic"

# Deploy the new database
Invoke-ASCmd –InputFile "$tabularModelDeploymentLocation $tabularModelName.json" -Server $serverName
# Process the new database
Invoke-ASCmd -Server $serverName -Query "{""refresh"":{""type"": ""$refreshType"", ""objects"": [{""database"": ""$tabularModelName""}]}}"


#Write-Output $tableObject