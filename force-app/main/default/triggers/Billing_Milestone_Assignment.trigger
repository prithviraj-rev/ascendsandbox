trigger Billing_Milestone_Assignment on SFDC_Timecard__c (before insert, before update) {
    
    map<Id,list<Date>> plmid = new map<Id,list<Date>>();
    map<Id,list<Date>> mid = new map<Id,list<Date>>();
    map<Id,Id> pli2p = new map<Id,Id>();
    map<string,boolean> existing =new map<string,boolean>();
    map<Id,map<Date,Id>> mimdi = new map<Id,map<Date,Id>>();
    //RecordType r=[select Id from RecordType where name='T&M Milestones' and SobjectType='Project_Monthly_Billing_Milestones__c'];
    //RecordType based on Billing Type, using the same one for now.
    map<string, id> rtMap = new map<string, Id>();
    rtMap.put('T&M', Schema.SObjectType.Project_Monthly_Billing_Milestones__c.getRecordTypeInfosByDeveloperName().get('T_M_Milestones').getRecordTypeId());
    rtMap.put('MRR', Schema.SObjectType.Project_Monthly_Billing_Milestones__c.getRecordTypeInfosByDeveloperName().get('T_M_Milestones').getRecordTypeId());
    rtMap.put('Prepaid', Schema.SObjectType.Project_Monthly_Billing_Milestones__c.getRecordTypeInfosByDeveloperName().get('T_M_Milestones').getRecordTypeId());
    map<id, string> projectToBillingType = new map<id, string>();
    
    map<Id,list<Project_Monthly_Billing_Milestones__c>> mileStones = new map<Id,list<Project_Monthly_Billing_Milestones__c>>();
    list<Project_Monthly_Billing_Milestones__c> newMS = new list<Project_Monthly_Billing_Milestones__c>();
    for(SFDC_Timecard__c tc:trigger.new){
        if(!plmid.containskey(tc.Project_Line_Item__c))plmid.put(tc.Project_Line_Item__c, new list<Date>());
        plmid.get(tc.Project_Line_Item__c).add(tc.Date__c);
    }
    //Add additional Billing type MRR
    for(Project_Line_Item__c p:[Select Id, Project__c, Project__r.Billing__c from Project_Line_Item__c 
                                where Id IN:plmid.keyset() and Project__r.Billing__c in ('T&M','MRR','Prepaid')]){
                                    if(!mid.containskey(p.Project__c))mid.put(p.Project__c, new list<Date>());
                                    mid.get(p.Project__c).addall(plmid.get(p.Id));
                                    if(!mimdi.containskey(p.Id))mimdi.put(p.Id, new map<Date,Id>());
                                    pli2p.put(p.Id,p.Project__c);
                                    projectToBillingType.put(p.Project__c, p.Project__r.Billing__c);
                                }
    for(Project_Monthly_Billing_Milestones__c bm:[Select Id,Project__c,Services_Month__c from Project_Monthly_Billing_Milestones__c 
                                                  where Project__c IN:mid.keyset()]){
                                                      if(!mileStones.containskey(bm.Project__c)) {
                                                          mileStones.put(bm.Project__c,new list<Project_Monthly_Billing_Milestones__c>());
                                                      }
                                                      mileStones.get(bm.Project__c).add(bm);                                              
                                                  }
    for(Id pId:mid.keySet()){
        for(Date d:mid.get(pId)){
            string key=string.valueof(pid)+string.valueOf(d.toStartOfMonth());
            if(!existing.containskey(key))existing.put(key,false);
            if(mileStones.containskey(pId)){
                for(Project_Monthly_Billing_Milestones__c bm:mileStones.get(pId)){
                    if(d.toStartOfMonth()==bm.Services_Month__c){
                        existing.put(key,true);
                        if(!mimdi.containskey(pid))mimdi.put(pid,new map<Date,Id>());
                        mimdi.get(pid).put(bm.Services_Month__c,bm.Id);
                    }
                }
            }
            if(!existing.get(key)){
                //Recordtype selection based on project type.
                Id rt = rtmap.get(projectToBillingType.get(pId));
                newMS.add(new Project_Monthly_Billing_Milestones__c(name='New',Project__c=pId,Services_Month__c=d.toStartOfMonth(),RecordTypeId=rt));
                existing.put(key,true);
            }
        }
    }
    if(newMS.size()>0)insert newMS;
    for(Project_Monthly_Billing_Milestones__c bm:newMS){
        if(!mimdi.containskey(bm.Project__c))mimdi.put(bm.Project__c,new map<Date,Id>());
        mimdi.get(bm.Project__c).put(bm.Services_Month__c,bm.Id);
    }
    for(SFDC_Timecard__c tc:trigger.new){
        date dbm = tc.Date__c.toStartOfMonth();
        tc.Billing_Milestones__c=null;
        if(pli2p.containsKey(tc.Project_Line_Item__c) && mimdi.containsKey(pli2p.get(tc.Project_Line_Item__c)) && mimdi.get(pli2p.get(tc.Project_Line_Item__c)).containsKey(dbm))
            tc.Billing_Milestones__c=mimdi.get(pli2p.get(tc.Project_Line_Item__c)).get(dbm);
    }
}