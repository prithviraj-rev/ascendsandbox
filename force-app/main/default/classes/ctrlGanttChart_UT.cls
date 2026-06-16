@isTest
private class ctrlGanttChart_UT {

    static testMethod void ctrlGanttChartTest() {
        Account a = new account(name='Test', BillingState = 'IL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        
        Contact c = new Contact(LastName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, Status__c='Active', External_Resource__c=false);
        insert c;

        SFDC_Projects__c p = new SFDC_Projects__c(name='test', Account__c = a.Id);
        insert p;
        Project_Line_Item__c pli = new Project_Line_Item__c(name='test', project__c=p.Id);
        insert pli;

        SFDC_Assignment__c ass = new SFDC_Assignment__c();
        ass.resource__c=c.Id;
        ass.Start_Date__c=date.today().addDays(-20); 
        ass.End_Date__c=date.today().addDays(20);
        ass.Number_Of_Hours__c=10;
        ass.Projects__c = p.id;
        insert ass;
        
        Contact[] cList = ctrlGanttChart.getResources();
        
        SFDC_Assignment__c[] aList = ctrlGanttChart.getAssignments(cList[0].Id);
  
    }
}