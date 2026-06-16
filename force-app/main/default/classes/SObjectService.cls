/******************************************************************************
// Summary:         Service class that implements business logic and methods for working with SF metadata objects
// Test Class:      SObjectServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 04/29/2024 - created
*******************************************************************************/

public without sharing class SObjectService 
{
    private static SObjectService instance;

	/*********************** STATIC SECTION ***********************/

	public static SObjectService getInstance()
	{
		if(instance == null) instance = new SObjectService();
		return instance;
	}

	/*********************** PUBLIC SECTION ***********************/

    public sObject loadSObject(ID recordId)
    {
        return loadSObject(recordId, null);
    }
    
    public sObject loadSObject(ID recordId, Set<String> additionalFields)
    {
        if(recordId == null) return null;
        List<sObject> records = loadSObjects(recordId.getSObjectType().getDescribe().getLocalName(), 'Id=\'' + recordId + '\'', additionalFields);
        return records.size() > 0 ? records[0] : null;
    }

    public List<sObject> loadSObjects(String objectType, String conditions, Set<String> additionalFields)
    {
        return loadSObjects(objectType, conditions, additionalFields, null, null, null);
    }
    
    public List<sObject> loadSObjects(String objectType, String conditions, Set<String> additionalFields, String orderBy, String offset, String resultLimit)
    {
        Set<String> lowerFields = new Set<String>();
        for(String fieldName : getSObjectFields(objectType))
            lowerFields.add(fieldName.toLowerCase());
   
        if(additionalFields != null)
        {
            for(String fieldName : additionalFields)
                lowerFields.add(fieldName.toLowerCase());
        }
        
        return loadSObjects(objectType, lowerFields, conditions, orderBy, offset, resultLimit);
    }

    public List<sObject> loadSObjects(String objectType, Set<String> fields, String conditions, String orderBy, String offset, String resultLimit)
    {
        return loadSObjects(objectType, fields, conditions, orderBy, offset, resultLimit, null);
    }

    public List<sObject> loadSObjects(String objectType, Set<String> fields, String conditions, String orderBy, String offset, String resultLimit, List<Object> params)
    {
        if(fields == null || fields.isEmpty())
		{
			fields = new Set<String>();
	        for(String fieldName : getSObjectFields(objectType))
	            fields.add(fieldName.toLowerCase());
		}

        String query = 'select ' + String.join(new List<String>(fields), ',') + ' from ' + objectType;
        if(!String.isEmpty(conditions)) query += ' where ' + conditions;
        if(!String.isEmpty(orderBy)) query += ' order by ' + orderBy;
        if(!String.isEmpty(resultLimit)) query += ' limit ' + resultLimit;
        if(!String.isEmpty(offset)) query += ' offset ' + offset;
		
		return (!String.isEmpty(offset) ? loadSObjectsWithOffset(query, params) : loadSObjects(query, params));
    }
    
	public List<sObject> loadSObjects(String query)
    {
        return loadSObjects(query, null);
	}

    public List<sObject> loadSObjects(String query, List<Object> params)
    {
        Object param1 = (params != null && params.size() > 0 ? params[0] : null),
                param2 = (params != null && params.size() > 1 ? params[1] : null),
                param3 = (params != null && params.size() > 2 ? params[2] : null),
                param4 = (params != null && params.size() > 3 ? params[3] : null),
                param5 = (params != null && params.size() > 4 ? params[4] : null); 
        
		System.debug(query);
        return Database.query(query);
	}

    public List<sObject> loadSObjectsWithOffset(String query) 
    {
        return loadSObjectsWithOffset(query, null);
    }

	public List<sObject> loadSObjectsWithOffset(String query, List<Object> params)
    {
        Object param1 = (params != null && params.size() > 0 ? params[0] : null),
                param2 = (params != null && params.size() > 1 ? params[1] : null),
                param3 = (params != null && params.size() > 2 ? params[2] : null),
                param4 = (params != null && params.size() > 3 ? params[3] : null),
                param5 = (params != null && params.size() > 4 ? params[4] : null); 
        
		System.debug(query);
		List<sObject> result = new List<sObject>();
		for(sObject record : Database.query(query))
			result.add(record);

        return result;
	}

    public Set<String> getSObjectFields(String objectType)
    {
        return Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap().keySet();
    }
}