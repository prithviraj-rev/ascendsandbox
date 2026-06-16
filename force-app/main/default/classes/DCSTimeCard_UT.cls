@isTest
public class DCSTimeCard_UT {
    @TestSetup
    public static void setupData(){
        User myself = [select id, firstname, lastname from user where id=:userinfo.getUserId()];
        
        Account a = new account(name='Test', BillingState = 'IL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        Contact c = new Contact(LastName=myself.lastname, FirstName=myself.firstName, accountId=a.Id, RecordTypeId=lr[0].Id, Resource_User_Record__c = UserInfo.getUserId(), MailingCountry = 'US', MailingState = 'AL');
        insert c;

        SFDC_Projects__c p = new SFDC_Projects__c(name='test', account__c=a.Id);
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
        
        date testDate = date.today().addDays(-7);
        
        list<SFDC_Timecard__c> timeEntries = new list<SFDC_Timecard__c>();
        timeEntries.add(new SFDC_Timecard__c(Assignment__c=ass.Id, date__c=testDate, Hours__c=2, Project_Line_Item__c=pli.Id));
		insert timeEntries;
    }
    public static testmethod void testProjectTree(){
        list<contact> res = [select id, accountId from contact];
        list<DCSTimeCardController.ProjectLevel> pl =  DCSTimeCardController.getProjectTree(res[0]);
    }
    public static testmethod void testTeamTree(){
        list<contact> res = [select id, accountId, Firstname, Lastname from contact];
        DCSTimeCardController.delegateInfo dopt = DCSTimeCardController.getDelegateOptions();
        DCSTimeCardController.TeamTree tl =  DCSTimeCardController.getTeamProjectTree(res[0]);
    }
    
    public static testmethod void testTypes(){
        list<string> tcType = DCSTimeCardController.getTimecardTypes();
    }
    public static testmethod void testDates(){
        date start = DCSTimeCardController.StartOfPeriod(-1);
        system.debug(start);
    }
    public static testmethod void testEntry(){
        DCSTimeCardController.BillingPeriod tc = DCSTimeCardController.getTimecards(-1, null, 'Billing Period');

        tc = DCSTimeCardController.getTimecards(-1, null, 'Week');

        system.debug(tc);
    }

    public static testmethod void testSubmitTimesheet(){
        Account a = [select Id from Account limit 1];
        Contact c = [select Id from Contact limit 1];
        Date startDate = system.today().toStartOfWeek();
        Date endDate = startDate.addDays(6);

        Timesheet__c timesheet = new Timesheet__c(Start_Date__c = startDate, End_Date__c = endDate, Resource__c = c.Id, Distinct_Id__c = string.valueOf(c.Id).left(15) + string.valueOf(startDate));
        insert timesheet;

        DCSTimeCardController.submitTimesheet(timesheet.Id);
    }
}