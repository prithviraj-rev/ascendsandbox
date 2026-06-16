trigger timecard_timesheet_assignment on SFDC_Timecard__c (before insert, before update) {
    string DEFAULT_OWNER = 'Heidi Perez';
    map<string,Id> msi = new map<string,Id>();
    map<string,SFDC_timecard__c> mstc = new map<string,SFDC_timecard__c>();
    map<Id,String> resources = new map<Id,String>();
    map<String,Id> owners = new map<String,Id>();
    for (SFDC_timecard__c tc:trigger.new){
        date startDate = (tc.Date__c.toStartOfWeek() > tc.Date__c.toStartOfMonth())?tc.Date__c.toStartOfWeek():tc.Date__c.toStartOfMonth();
        string key = string.valueOf(tc.Resource_Id__c).left(15)+string.valueOf(startDate);
        msi.put(key,null);
        mstc.put(key,tc);
        resources.put(tc.Resource_Id__c,tc.Resource__c);
    }
    for(User u:[Select Id, Name from User where (Name IN:resources.values() or Name =:DEFAULT_OWNER) and IsActive = true]){
            owners.put(u.Name,u.Id);    
    }
    for(Timesheet__c t :[Select Id, Distinct_Id__c from Timesheet__c where Distinct_Id__c IN:msi.keySet()]){
        msi.put(t.Distinct_Id__c,t.Id);    
    }
    map<string,Timesheet__c> newTimesheets = new map<string,Timesheet__c>();
    for(string s:msi.keySet()){
        if(msi.get(s)==null && !newTimesheets.containsKey(s)){
            SFDC_timecard__c tc = mstc.get(s);
            date startDate = tc.Date__c.toStartOfWeek();
            date endDate = startDate.addDays(6);
            date startOfMonth = endDate.toStartOfMonth();
            if(startDate < startOfMonth){
                if(tc.Date__c >= startOfMonth)
                    startDate = startOfMonth;
                else
                    endDate = startOfMonth.addDays(-1);
            }
            
            Id i = (Id)tc.Resource_Id__c;
            Timesheet__c t = new Timesheet__c();
            t.Start_Date__c = startDate;
            t.End_Date__c = endDate;
            t.Resource__c = i;
            t.Distinct_Id__c = string.valueOf(i).left(15)+string.valueOf(startDate);
            
            ID ownerId = (owners.containsKey(resources.get(i)))?owners.get(resources.get(i)):owners.get(DEFAULT_OWNER);
            if(ownerId != null) t.OwnerId = ownerId;
            
            newTimesheets.put(t.Distinct_Id__c,t);    
        }       
    }
    if(newTimesheets.size()>0){
        insert newTimesheets.values();
        for(Timesheet__c t:newTimesheets.values()){
            msi.put(t.Distinct_Id__c,t.Id);
        }
    }
    for (SFDC_timecard__c tc:trigger.new){
        date startDate = (tc.Date__c.toStartOfWeek() > tc.Date__c.toStartOfMonth())?tc.Date__c.toStartOfWeek():tc.Date__c.toStartOfMonth();
        tc.Timesheet__c = msi.get(string.valueOf(tc.Resource_Id__c).left(15)+string.valueOf(startDate));
    }
}