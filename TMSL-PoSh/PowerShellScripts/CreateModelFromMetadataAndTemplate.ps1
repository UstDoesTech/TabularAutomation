# Variables which contain configurable information
$configDatabase = "ConfigDB"
$databaseName = "AdventureWorksDW2014"
$serverName = "localhost"
$userNameShort = "username"
$ServerAConnectionString = 'Data Source='+$serverName+';Initial Catalog='+$configDatabase+';User Id='+ $userNameShort +';Integrated Security = True'
$ServerAConnection = new-object system.data.SqlClient.SqlConnection($ServerAConnectionString);

$tabularModelName = "AdventureWorksTemplateAndMetadata"
$tabularModelDeploymentLocation = "C:\Temp\TabularModels\"
$masterFileLocation = "C:\Temp\Master\"

$impersonationMode = "impersonateAccount"
#$account = "DOMAIN\\USERNAME"
#$password = "PASSWORD"

# Initialise the tabular model
$tabularModel = ''

$createOrReplaceStatement = $masterFileLocation + '_Template_TMSL_CREATEorREPLACE.json'
$createOrReplaceStatement = Get-Content $createOrReplaceStatement | Out-String
$createOrReplaceStatement = $createOrReplaceStatement -replace "%TABULARMODELNAME%", $tabularModelName

if ($impersonationMode = "impersonateAccount") 
{
    $databaseObjectStatement = $masterFileLocation + '_Template_TMSL_DATABASE_USERACCOUNT.json'
    $databaseObjectStatement = Get-Content $databaseObjectStatement | Out-String
    $databaseObjectStatement = $databaseObjectStatement -replace "%TABULARMODELNAME%", $tabularModelName
    $databaseObjectStatement = $databaseObjectStatement -replace "%SERVERNAME%", $serverName
    $databaseObjectStatement = $databaseObjectStatement -replace "%DATABASENAME%", $databaseName
    $databaseObjectStatement = $databaseObjectStatement -replace "%IMPERSONATIONMODE%", $impersonationMode
    $databaseObjectStatement = $databaseObjectStatement -replace "%ACCOUNT%", $account
    $databaseObjectStatement = $databaseObjectStatement -replace "%PASSWORD%", $password
}
elseif($impersonationMode = "impersonateServiceAccount")
{
    $databaseObjectStatement = $masterFileLocation + '_Template_TMSL_DATABASE_SERVICEACCOUNT.json'
    $databaseObjectStatement = Get-Content $databaseObjectStatement | Out-String
    $databaseObjectStatement = $databaseObjectStatement -replace "%TABULARMODELNAME%", $tabularModelName
    $databaseObjectStatement = $databaseObjectStatement -replace "%SERVERNAME%", $serverName
    $databaseObjectStatement = $databaseObjectStatement -replace "%DATABASENAME%", $databaseName
    $databaseObjectStatement = $databaseObjectStatement -replace "%IMPERSONATIONMODE%", $impersonationMode
}

$tableObject = """tables"": [
          "
$tableNames = Invoke-Sqlcmd -Query "USE $configDatabase; WITH CTE AS (SELECT DISTINCT TargetTable FROM dbo.Tables  WHERE ObjectName = 'Column') SELECT TargetTable, ROW_NUMBER() OVER(order by TargetTable) AS rownum FROM CTE;"

# Find maximum number of tables that need to be processed
$tableRowNum = $tableNames.rownum
$tableRowNum = (($tableRowNum|Measure-Object -Maximum).Maximum) 
$tableRowNum = $tableRowNum[0]

# Add statements to the definition of the Tabular model
$tabularModel += $createOrReplaceStatement
$tabularModel += $databaseObjectStatement
$tabularModel += $tableObject

$n = 1

foreach ($table in $tableNames)
{
    $tableName = $table.TargetTable
    $tableDefinition = Invoke-Sqlcmd -Query "USE $configDatabase;
    
			SELECT  SourceFullName, 
		            TargetColumn,
                    ROW_NUMBER() OVER(PARTITION BY TargetTable ORDER BY TargetColumn) AS RowNum
            FROM [dbo].[Tables]
            WHERE TargetTable = '$tableName'
            AND ObjectName = 'Column';"


    $fullyqualifiedname = $tableDefinition.SourceFullName[0]
    
    $tableObjects = "
            {""name"": ""$tableName"",
            ""columns"": ["

    $tabularModel += $tableObjects

    # Find maximum number of columns that need to be processed
    $rowNumber = $tableDefinition.RowNum
    $rowNum = (($rowNumber|Measure-Object -Maximum).Maximum) 
    $rowNum = $rowNum[0]
    
    $i = 1

    $columnList = ''
    
    foreach ($targetColumn in $tableDefinition.TargetColumn){

        $columnInformation = Invoke-Sqlcmd -Query "USE $configDatabase;
                SELECT   [SourceTable]
                        ,[SourceColumn]
                        ,[IsHidden]
                FROM [dbo].[Tables]
                WHERE TargetTable = '$tableName'
	                AND TargetColumn = '$targetColumn'
	                AND ObjectName = 'Column'"
        $sourceColumn = $columnInformation.SourceColumn
        $sourceTable = $columnInformation.SourceTable
        $isHidden = $columnInformation.IsHidden

        $dataTypeQuery = Invoke-Sqlcmd -Query "USE $databaseName;
            WITH CTE AS (
	    		SELECT  
	    		        Table_Name AS TableName,
	    				Column_Name AS ColumnName, 
	    				CONCAT(Data_Type, CASE WHEN CHARACTER_MAXIMUM_LENGTH IS NULL
	    								THEN ''
	    								ELSE CONCAT('(', character_maximum_Length,')')END) AS DataType
	    		FROM information_schema.columns c
	    		INNER JOIN sys.objects o ON c.TABLE_NAME = o.name AND o.type = 'V' AND c.TABLE_SCHEMA <> 'dbo'
	    		)

            SELECT	TableName, 
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
            WHERE TableName = '$sourceTable' AND ColumnName = '$sourceColumn'"

        $tabularDataType = $dataTypeQuery.TabularDataType
        $sourceDataType = $dataTypeQuery.SourceDataType

        $columnObjects = $masterFileLocation + '_Template_TMSL_COLUMN.json'
        $columnObjects = Get-Content $columnObjects | Out-String
        $columnObjects = $columnObjects -replace "%TABULARCOLUMN%", $targetColumn
        $columnObjects = $columnObjects -replace "%TABULARDATATYPE%", $tabularDataType
        $columnObjects = $columnObjects -replace "%HIDDENCOLUMN%", $isHidden
        $columnObjects = $columnObjects -replace "%SOURCECOLUMN%", $sourceColumn
        $columnObjects = $columnObjects -replace "%SOURCEDATATYPE%", $sourceDataType
        
        # if statement to append a comma at the right place
        If ($i -lt $rowNum)
        {$columnObjects += ","}

        If ($i -eq $rowNum)
        {$columnObjects += "],"}
        
        $tabularModel += $columnObjects

        # Populate list of columns for the partition
        $columnList += $sourceColumn
        If ($i -lt $rowNum)
        {$columnList += ","}

        $i = $i + 1

    }

    $tabularModel += "
            ""partitions"": [
              {
                ""name"": ""$tableName"",
                ""dataView"": ""full"",
                ""source"": {
                  ""query"": "" SELECT $columnList FROM $fullyqualifiedname "",
                  ""dataSource"": ""SqlServer $serverName $databaseName""
                }
              }
            ]
            "
    #
    $measureTable = Invoke-Sqlcmd -Query "USE $configDatabase; 
                                            SELECT TargetTable 
                                            FROM dbo.Tables 
                                            WHERE ObjectName = 'Measure' 
                                            AND TargetTable = '$tableName';"
    #
    if($measureTable)
    {

      $tabularModel += ",
        ""measures"": ["
      $tableDefinition = Invoke-Sqlcmd -Query "USE $configDatabase;
    
			SELECT  TargetColumn,
                    ROW_NUMBER() OVER(PARTITION BY TargetTable ORDER BY TargetColumn) AS RowNum
            FROM [dbo].[Tables]
            WHERE TargetTable = '$tableName'
            AND ObjectName = 'Measure';"  

        # Find maximum number of columns that need to be processed
        $rowNumber = $tableDefinition.RowNum
        $rowNum = (($rowNumber|Measure-Object -Maximum).Maximum) 
        $rowNum = $rowNum[0]
    
        $i = 1

        foreach($measureName in $tableDefinition.TargetColumn)
        {
            $measureInformation = Invoke-Sqlcmd -Query "USE $configDatabase;
                SELECT   [Measure]
                        ,[IsHidden]
                FROM [dbo].[Tables]
                WHERE TargetTable = '$tableName'
	                AND TargetColumn = '$measureName'
	                AND ObjectName = 'Measure'"
            $measureExpression = $measureInformation.Measure
            $isHidden = $measureInformation.IsHidden

            $measureFormat = ''

            $measureObjects = $masterFileLocation + '_Template_TMSL_MEASURE.json'
            $measureObjects = Get-Content $measureObjects | Out-String
            $measureObjects = $measureObjects -replace "%MEASURENAME%", $measureName
            $measureObjects = $measureObjects -replace "%MEASUREEXPRESSION%", $measureExpression
            $measureObjects = $measureObjects -replace "%MEASUREFORMAT%", $measureFormat
            $measureObjects = $measureObjects -replace "%HIDDENCOLUMN%", $isHidden

            # if statement to append a comma at the right place
            If ($i -lt $rowNum)
            {$measureObjects += ","}

            If ($i -eq $rowNum)
            {$measureObjects += "]"}
        
            $tabularModel += $measureObjects

            $i = $i + 1

        }
    
    }

    #
    $hierarchyTable = Invoke-Sqlcmd -Query "USE $configDatabase; 
                                            SELECT TargetTable 
                                            FROM dbo.Tables 
                                            WHERE ObjectName = 'Hierarchy' 
                                            AND SourceTable = '$tableName';"
    #
    if($hierarchyTable)
    {

      $tabularModel += ",
        ""hierarchies"": [
            "

      $hierarchyNames = Invoke-Sqlcmd -Query "USE $configDatabase; WITH CTE AS (SELECT DISTINCT TargetTable FROM dbo.Tables  WHERE ObjectName = 'Hierarchy' AND SourceTable = '$tableName') SELECT TargetTable, ROW_NUMBER() OVER(order by TargetTable) AS rownum FROM CTE;"
      
      # Find maximum number of tables that need to be processed
      $hierarchyRowNum = $hierarchyNames.rownum
      $hierarchyRowNum = (($hierarchyRowNum|Measure-Object -Maximum).Maximum) 
      $hierarchyRowNum = $hierarchyRowNum[0]

      $h = 1

      foreach($hierarchy in $hierarchyNames.TargetTable)
      {
        $tabularModel += "
        {
        ""name"": ""$hierarchy"",
        ""levels"": [
        "

        $hierarchyDefinition = Invoke-Sqlcmd -Query "USE $configDatabase;
    
			SELECT  TargetColumn, HierarchyOrdinal
            FROM [dbo].[Tables]
            WHERE TargetTable = '$hierarchy'
            AND ObjectName = 'Hierarchy'
            ORDER BY HierarchyOrdinal ASC;"
        $maximumOrdinal = $hierarchyDefinition.HierarchyOrdinal
        $maximumOrdinal = (($maximumOrdinal|Measure-Object -Maximum).Maximum) 
        $maximumOrdinal = $maximumOrdinal[0]

        $hc = 0

        foreach($hierachyColumn in $hierarchyDefinition.TargetColumn)
        {
            $hierarchyInformation = Invoke-Sqlcmd -Query "USE $configDatabase;
                SELECT   [HierarchyOrdinal]
                        ,[SourceColumn]
                FROM [dbo].[Tables]
                WHERE TargetTable = '$hierarchy'
	                AND TargetColumn = '$hierachyColumn'
	                AND ObjectName = 'Hierarchy'"
            $hierarchyOrdinal = $hierarchyInformation.HierarchyOrdinal
            $sourceColumn = $hierarchyInformation.SourceColumn

            $hierarchyObjects = $masterFileLocation + '_Template_TMSL_HIERARCHY.json'
            $hierarchyObjects = Get-Content $hierarchyObjects | Out-String
            $hierarchyObjects = $hierarchyObjects -replace "%HIERARCHYCOLUMN%", $hierachyColumn
            $hierarchyObjects = $hierarchyObjects -replace "%HIERARCHYORDINAL%", $hierarchyOrdinal
            $hierarchyObjects = $hierarchyObjects -replace "%SOURCECOLUMN%", $sourceColumn

            # if statement to append a comma at the right place
            If ($hc -lt $maximumOrdinal)
            {$hierarchyObjects += ","}
            
            $tabularModel += $hierarchyObjects
            
            $hc = $hc + 1

        }

        # if statement to append a comma at the right place
            If ($h -lt $hierarchyRowNum)
            {$tabularModel += "]},"}

            If ($h -eq $hierarchyRowNum)
            {$tabularModel += "]}]"}
        
            $h = $h + 1
      
      }
    
    }
    
    # If statement to assign a comma at the end of the block
    If ($n -lt $tableRowNum)
    {$tabularModel += "},"}

    If ($n -eq $tableRowNum)
    {$tabularModel += "}],"}

    $n = $n + 1
    
}

$relationshipObject = """relationships"": [
          "
$relationshipNames = Invoke-Sqlcmd -Query "USE $configDatabase; WITH CTE AS (SELECT DISTINCT RelationshipName FROM dbo.Relationships) SELECT RelationshipName, ROW_NUMBER() OVER(order by RelationshipName) AS rownum FROM CTE;"

# Find maximum number of tables that need to be processed
$relationshipRowNum = $relationshipNames.rownum
$relationshipRowNum = (($relationshipRowNum|Measure-Object -Maximum).Maximum) 
$relationshipRowNum = $relationshipRowNum[0]

# Add statements to the definition of the Tabular model
$tabularModel += $relationshipObject

$r = 1

foreach ($relationshipName in $relationshipNames.RelationshipName)
{
    $relationshipInformation = Invoke-Sqlcmd -Query "USE $configDatabase;
                SELECT	FromTable,
                		FromColumn,
                		FromCardinality,
                		ToTable,
                		ToColumn,
                		ToCardinality,
                		IsActive
                FROM [dbo].Relationships
                WHERE RelationshipName = '$relationshipName'"

     $fromTable = $relationshipInformation.FromTable
     $fromColumn = $relationshipInformation.FromColumn
     $fromCardinality = $relationshipInformation.FromCardinality
     $toTable = $relationshipInformation.ToTable
     $toColumn = $relationshipInformation.ToColumn
     $toCardinality = $relationshipInformation.ToCardinality
     $isActive = $relationshipInformation.IsActive

     $relationshipObjects = $masterFileLocation + '_Template_TMSL_RELATIONSHIP.json'
     $relationshipObjects = Get-Content $relationshipObjects | Out-String
     $relationshipObjects = $relationshipObjects -replace "%RELATIONSHIPNAME%", $relationshipName
     $relationshipObjects = $relationshipObjects -replace "%FROMTABLE%", $fromTable
     $relationshipObjects = $relationshipObjects -replace "%FROMCOLUMN%", $fromColumn
     $relationshipObjects = $relationshipObjects -replace "%FROMCARDINALITY%", $fromCardinality
     $relationshipObjects = $relationshipObjects -replace "%TOTABLE%", $toTable
     $relationshipObjects = $relationshipObjects -replace "%TOCOLUMN%", $toColumn
     $relationshipObjects = $relationshipObjects -replace "%TOCARDINALITY%", $toCardinality
     $relationshipObjects = $relationshipObjects -replace "%ISACTIVE%", $isActive

     $tabularModel += $relationshipObjects

     # If statement to assign a comma at the end of the block
    If ($r -lt $relationshipRowNum)
    {$tabularModel += ","}

    If ($r -eq $relationshipRowNum)
    {$tabularModel += "]"}

    $r = $r + 1

}



$roleTable = Invoke-Sqlcmd -Query "USE $configDatabase; 
                                    SELECT RoleName 
                                    FROM dbo.Roles;"
if($roleTable)
{
    $roleDefinition = Invoke-Sqlcmd -Query "USE $configDatabase;
        SELECT  RoleName, 
                ROW_NUMBER() OVER(ORDER BY RoleName) as RowNum
        FROM [dbo].[Roles];"
    $roleRowNumber = $roleDefinition.RowNum
    $roleRowNumber = (($roleRowNumber|Measure-Object -Maximum).Maximum) 
    $roleRowNumber = $roleRowNumber[0]

    $roleObject = ",
            ""roles"": [
                                "
    # Add statements to the definition of the Tabular model
    $tabularModel += $roleObject

    $r = 1
    # Loop through the roles and create definitions for them
    # Cannot assign members to roles, due to GUID from AD
    foreach($roleName in $roleDefinition.RoleName)
    {
        $roleInformation = Invoke-Sqlcmd -Query "USE $configDatabase;
            SELECT ModelPermissions
            FROM dbo.Roles
            WHERE RoleName = '$roleName';"
        $modelPermissions = $roleInformation.ModelPermissions

        $roleObjects = $masterFileLocation + '_Template_TMSL_ROLE.json'
        $roleObjects = Get-Content $roleObjects | Out-String
        $roleObjects = $roleObjects -replace "%ROLENAME%", $roleName
        $roleObjects = $roleObjects -replace "%MODELPERMISSION%", $modelPermissions

        $tabularModel += $roleObjects

        # If statement to assign a comma at the end of the block
        If ($r -lt $roleRowNumber)
        {$tabularModel += ","}

        If ($r -eq $roleRowNumber)
        {$tabularModel += "]"}

        $r = $r + 1
    }


}







# Close the Tabular model statement
$tabularModel += "
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

# Add member to role
 #add-rolemember –membername "Domain\User" -database "$tabularModelName" -rolename "ReaderRole"