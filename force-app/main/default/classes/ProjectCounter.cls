global class ProjectCounter implements database.Batchable<sObject>{

    global Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('select id, Projects_Over_2_Years__c, Projects_Last_2_Years__c from account');
    }
    global void execute(Database.BatchableContext bc, List<account> scope){
        
        map<id,Account> batchMap = new map<id,Account>(scope);
        map<id,Account> updateMap = new map<id,Account>();
        set<Id>processed = new set<Id>();
        list<aggregateresult> agg = [select Account__c, count(Id) cnt from sfdc_Projects__c 
                                     where Account__c in:batchmap.keyset() and End_Date__c < LAST_N_DAYS:730
                                    group by Account__c];
        for (aggregateresult ar:agg){
            Account inspect = batchmap.get((Id)ar.get('Account__c'));
            integer projectsOver = (Integer)ar.get('cnt');
            if (projectsOver!=inspect.Projects_Over_2_Years__c){
                inspect.Projects_Over_2_Years__c=projectsOver;
                updateMap.put(inspect.Id, inspect);
            }
			processed.add(inspect.Id);
        }        
        set<Id> delta = batchmap.keyset().clone();
        delta.removeAll(processed);
        for (Id accountId: delta){
           	Account inspect = batchmap.get(accountID);
            if (inspect.Projects_Over_2_Years__c!=0){
                inspect.Projects_Over_2_Years__c=0;
                updateMap.put(inspect.Id, inspect);
            }
        }
        processed.clear();
        
         agg = [select Account__c, count(Id) cnt from sfdc_Projects__c 
                                     where Account__c in:batchmap.keyset() and End_Date__c >= LAST_N_DAYS:730
                                    group by Account__c];
        for (aggregateresult ar:agg){
            Account inspect = batchmap.get((Id)ar.get('Account__c'));
            integer projectsIn = (Integer)ar.get('cnt');
            if (projectsIn!=inspect.Projects_Last_2_Years__c){
                inspect.Projects_Last_2_Years__c=projectsIn;
                updateMap.put(inspect.Id, inspect);
            }
			processed.add(inspect.Id);

        }
        delta = batchmap.keyset().clone();
        delta.removeAll(processed);
        for (Id accountId: delta){
           	Account inspect = batchmap.get(accountID);
            if (inspect.Projects_Last_2_Years__c!=0){
                inspect.Projects_Last_2_Years__c=0;
                updateMap.put(inspect.Id, inspect);
            }
        }
        if (updateMap.size()>0){
            update updateMap.values();
            system.debug(json.serializepretty(updateMap.values()));
        }
    }
    global void finish(Database.BatchableContext bc){
        
    }
}