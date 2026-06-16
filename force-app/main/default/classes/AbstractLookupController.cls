/******************************************************************************
// Summary:         The class controller for abstractLookup LWC component
// Test Class:      AbstractLookupControllerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/12/2024 - created
*******************************************************************************/

public with sharing class AbstractLookupController implements Callable 
{
    public Object search(String objectName, String valueField, String value, String searchField, String searchValue, String conditions, String limitValue, String searchClass)
    {
        if(!String.isBlank(searchClass)) {
            Type instanceType = Type.forName(searchClass);
			Callable instance = (Callable)instanceType.newInstance();
			return instance.call('search', new Map<String, Object> {
                'objectName' => objectName,
                'valueField' => valueField,
                'value' => value,
                'searchField' => searchField,
                'searchValue' => searchValue,
                'conditions' => conditions,
                'limitValue' => limitValue
            });
        }

        List<Object> result = new List<Object>();
        if(String.isEmpty(objectName)) return result;

        Schema.DescribeSObjectResult describe = Schema.getGlobalDescribe().get(objectName).getDescribe();
        if(String.isEmpty(searchField)) searchField = findSObjectNameField(describe);
        if(String.isEmpty(searchValue)) searchValue = '';
        if(String.isEmpty(limitValue)) limitValue = '100';
        if(String.isEmpty(valueField)) valueField = 'id';
        
        searchField = searchField.remove(' ');
        List<String> searchFields = searchField.split(',');
        if(searchFields.size() > 1) searchField = searchFields[0];

        searchValue = String.escapeSingleQuotes(searchValue).replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');

        Set<ID> recentlyViewedIds = new Set<ID>();
        if(String.isBlank(searchValue)) {
            Integer limitNumber = Integer.valueOf(limitValue);
            for(RecentlyViewed record : [select Id FROM RecentlyViewed WHERE Type = :objectName limit :limitNumber]) {
                recentlyViewedIds.add(record.Id);
            }

            if(recentlyViewedIds.size() > 0) conditions = (String.isEmpty(conditions) ? '' : conditions + ' and ') + 'Id in :recentlyViewedIds';
        }

        Set<String> fieldNames = new Set<String>{searchField.toLowerCase(), valueField.toLowerCase()};
        String query = 'select ' + String.join(new List<String>(fieldNames), ',') + ' from ' + objectName;
        if(!String.isEmpty(value)) 
        {
            Schema.DescribeFieldResult valueFieldDescribe = describe.fields.getMap().get(valueField).getDescribe();
            if(valueFieldDescribe.getType() != Schema.DisplayType.ID || value instanceof ID)
                query += ' where ' + valueField + ' =\'' + value + '\'';
        }else{
            List<String> searchConditions = new List<String>();
            for(String fieldName : searchFields) {
                searchConditions.add('(' + fieldName + ' != null and ' + fieldName + ' like \'%' + searchValue + '%\')');
            }

            query += ' where (' + String.join(searchConditions, ' or ') + ')';
            if(!String.isEmpty(conditions)) query += ' and ' + conditions;
        }

        if(recentlyViewedIds.size() > 0) {
            if(Database.query(query + ' limit 1').size() == 0) {
                query = query.remove(' and Id in :recentlyViewedIds').remove('Id in :recentlyViewedIds');
            }
        }
        
        query += ' order by ' + searchField + ' asc';
        query += ' limit ' + limitValue;
    
        List<Sobject> objects = Database.query(query);
        Map<String, sObject> objectMap = new Map<String, sObject>();
        for(Sobject record : objects)
        {
            String key = String.valueOf(record.get(searchField)) + String.valueOf(record.get('Id'));
            objectMap.put(key, record);
        }
        
        List<String> keys = new List<String>(objectMap.keySet());
        keys.sort();

        Object valueObject = (!String.isEmpty(value) && value instanceof ID ? (Object)(ID)value : (Object)value);
        for(String key : keys)
        {
            Sobject record = objectMap.get(key);
            result.add(new Map<String, Object>{
                'value' => String.valueOf(record.get(valueField)), 
                'label' => String.valueOf(record.get(searchField)), 
                'selected' => record.get(valueField) == valueObject
            });
        }
    
    	return result;
    }

    private static String findSObjectNameField(Schema.DescribeSObjectResult describe)
    {
        if(describe.fields.getMap().containsKey('name') && describe.fields.getMap().get('name').getDescribe().isNameField()) return 'name';
        for(Schema.sObjectField field : describe.fields.getMap().values())
        {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            if(fieldDescribe != null && fieldDescribe.isNameField()) return fieldDescribe.getLocalName();
        }

        return 'id';
    }

    /*************************** CALLABLE SECTION **********************************/

	public Object call(String actionName, Map<String, Object> params) 
	{
		switch on actionName {
            when 'search' {
                return search(
                    (String)params.get('objectName'),
                    (String)params.get('valueField'),
                    (String)params.get('value'),
                    (String)params.get('searchField'),
                    (String)params.get('searchValue'),
                    (String)params.get('conditions'),
                    (String)params.get('limitValue'),
                    (String)params.get('searchClass')
                );
			}

		  	when else {
				throw new AuraHelper.AuraException('Invalid action name.');
		  	}
		}
	}
}