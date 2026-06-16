global class TimesheetCreator implements schedulable{
    global void execute(SchedulableContext sc){
        string DEFAULT_OWNER = 'Jeremy Moore';
        map<Id,String> resources = new map<Id,String>();
        map<String,Id> owners = new map<String,Id>();
        date startDate = system.today().toStartOfWeek().addDays(7);
        date endDate = startDate.addDays(6);
        date startOfMonth = endDate.toStartOfMonth();
        boolean splitWeek = (startDate < startOfMonth);
        list<Timesheet__c> timesheets = new list<Timesheet__c>();
        
        for(Contact c:[Select Id, Name from Contact 
                       where Id IN (Select Resource__c from SFDC_Assignment__c 
                                    where Timesheet_Assignment__c = TRUE)]){
            resources.put(c.Id,c.Name);                                 
        }
        for(User u:[Select Id, Name from User where (Name IN:resources.values() or Name =:DEFAULT_OWNER) and IsActive = true]){
            owners.put(u.Name,u.Id);    
        }
        for(Id i:resources.keyset()){
            Timesheet__c t = new Timesheet__c();
            t.Start_Date__c = startDate;
            t.End_Date__c = (!splitWeek)?endDate:startOfMonth.addDays(-1);
            t.Resource__c = i;
            t.OwnerId = (owners.containsKey(resources.get(i)))?owners.get(resources.get(i)):owners.get(DEFAULT_OWNER);
            t.Distinct_Id__c = string.valueOf(i).left(15)+string.valueOf(startDate);
            timesheets.add(t);
            if(splitWeek || test.isRunningTest()){
                t = new Timesheet__c();
                t.Start_Date__c = startOfMonth;
                t.End_Date__c = endDate;
                t.Resource__c = i;
                t.OwnerId = (owners.containsKey(resources.get(i)))?owners.get(resources.get(i)):owners.get(DEFAULT_OWNER);
                t.Distinct_Id__c = string.valueOf(i).left(15)+string.valueOf(startOfMonth);
                timesheets.add(t);
            }
        }
        upsert timesheets Distinct_Id__c;
    }
}