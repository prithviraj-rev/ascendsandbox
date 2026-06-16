global class ResourceAssignmentShare implements schedulable{
    global void execute(SchedulableContext sc){
        map<Id,String> resources = new map<Id,String>();
        map<String,Id> owners = new map<String,Id>();
        map<Id,Id> contactOwner = new map<Id,Id>();
        
        for(User u:[Select Id, ContactId from User where ContactId != NULL and IsActive = true]){
        	contactOwner.put(u.ContactId,u.Id);    
        }
        
        map<string,SFDC_Assignment__Share> sas = new map<string,SFDC_Assignment__Share>();
        map<Id,SFDC_Assignment__c> mis = new map<Id,SFDC_Assignment__c>([Select Id, Resource__c,Projects__r.Account__c from SFDC_Assignment__c where Resource__c IN:contactOwner.keySet()]);
        map<string,AccountShare> saccs = new map<string,AccountShare>();
        set<Id> AccountIds = new set<Id>();
        for(SFDC_Assignment__c sfa:mis.values()){
            if(contactOwner.containsKey(sfa.Resource__c)){
        		sas.put(string.valueOf(sfa.Id)+','+string.valueOf(contactOwner.get(sfa.Resource__c)),null);
                if(sfa.Projects__r.Account__c != null){
                	saccs.put(string.valueOf(sfa.Projects__r.Account__c)+','+string.valueOf(contactOwner.get(sfa.Resource__c)),null);
                	AccountIds.add(sfa.Projects__r.Account__c);
                }
            }	
        }
        
        for(SFDC_Assignment__Share sfas:[Select ParentId, UserOrGroupId from SFDC_Assignment__Share where ParentId IN:mis.keySet()]){
            sas.remove(string.valueOf(sfas.ParentId)+','+string.valueOf(sfas.UserOrGroupId));
        }
        for(AccountShare acs:[Select AccountId, UserOrGroupId from AccountShare where AccountId IN:AccountIds]){
            saccs.remove(string.valueOf(acs.AccountId)+','+string.valueOf(acs.UserOrGroupId));
        }
        for(String key:sas.keySet()){
            system.debug(key);
        	SFDC_Assignment__c sfa = mis.get((Id)key.split(',')[0]);
            Id userId = (Id)key.split(',')[1];
            sas.put(key,new SFDC_Assignment__Share(ParentId = sfa.Id, UserOrGroupId = userId,AccessLevel = 'Read', RowCause = 'Manual'));
        }
        for(String key:saccs.keySet()){
            system.debug(key);
        	Id AccountId = (Id)key.split(',')[0];
            Id userId = (Id)key.split(',')[1];
            saccs.put(key,new AccountShare(AccountId = AccountId, UserOrGroupId = userId, RowCause = 'Manual',
                                           AccountAccessLevel = 'Read', CaseAccessLevel = 'None', OpportunityAccessLevel = 'None'));
        }
        if(sas.size()>0)
            insert sas.values();
        if(saccs.size()>0)
            insert saccs.values();
    }
}