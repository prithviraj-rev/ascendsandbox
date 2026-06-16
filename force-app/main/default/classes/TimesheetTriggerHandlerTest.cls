/******************************************************************************
// Summary:         Test class for TimesheetTriggerHandler

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/31/2024 - created
*******************************************************************************/

@IsTest
private class  TimesheetTriggerHandlerTest {
    @TestSetup
    static void initData()
    {
        Account a = new Account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name = 'Resource'];
        
        Contact c = new Contact(LastName = 'Test', FirstName = 'Test', accountId = a.Id, RecordTypeId = lr[0].Id, Employment_Type__c = '1099', MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c = a.Id,Project_Stage__c='Active');     
        insert proj;
        
        Date startDate = system.today().toStartOfWeek();
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(resource__c = c.Id, projects__c = proj.Id, Start_Date__c = startDate, End_Date__c = startDate.addDays(13), Number_Of_Hours__c = 67, Daily_Max__c = 10);
        insert assignment;
        
        Project_Line_Item__c pli = new Project_Line_Item__c();
        pli.Project__c = proj.id;
        insert pli;
    }

    @IsTest
    static void test() {
        Account a = [select Id from Account limit 1];
        Contact c = [select Id from Contact limit 1];
        SFDC_Projects__c proj = [select Id from SFDC_Projects__c limit 1];
        SFDC_Assignment__c assignment = [select Id from SFDC_Assignment__c limit 1];
        Project_Line_Item__c pli = [select Id from Project_Line_Item__c limit 1];

        Date startDate = system.today().toStartOfWeek();
        Date endDate = startDate.addDays(6);
        Date nextWeekMonday = startDate.addDays(8);

        Timesheet__c timesheet = new Timesheet__c(Start_Date__c = startDate, End_Date__c = endDate, Resource__c = c.Id, Distinct_Id__c = string.valueOf(c.Id).left(15) + string.valueOf(startDate));
        insert timesheet;
        
        SFDC_Timecard__c timecard = new SFDC_Timecard__c(Date__c = startDate.addDays(2), Hours__c = 30, Assignment__c = assignment.Id, Timesheet__c = timesheet.Id, Project_Line_Item__c = pli.Id);
        insert timecard;
        
        timesheet.Status__c = 'Approved';
        update timesheet;
        
        Daily_Assignment__c dailyAssignment = [select Actual_Hours__c from Daily_Assignment__c where Assignment__c = :assignment.Id and Daily_Date__c = :startDate.addDays(2)];
        System.assertEquals(30, dailyAssignment.Actual_Hours__c);
        System.assertEquals(10, [select Projected_Hours__c from Daily_Assignment__c where Assignment__c = :assignment.Id and Daily_Date__c = :nextWeekMonday].Projected_Hours__c);
        System.assertEquals(7, [select Projected_Hours__c from Daily_Assignment__c where Assignment__c = :assignment.Id and Daily_Date__c = :nextWeekMonday.addDays(3)].Projected_Hours__c);

        RPRFAssignmentService.getInstance().clearDailyAssignments(assignment);
        System.assertEquals(0, [select id from  Daily_Assignment__c where Assignment__c = :assignment.Id].size());
        delete timesheet;
        
        timesheet = new Timesheet__c(Start_Date__c = startDate, End_Date__c = endDate, Resource__c = c.Id, Distinct_Id__c = string.valueOf(c.Id).left(15) + string.valueOf(startDate));
        insert timesheet;

        timecard = new SFDC_Timecard__c(Date__c = Date.today().toStartOfWeek(), Hours__c = 4.56, Assignment__c = assignment.Id, Timesheet__c = timesheet.Id, Project_Line_Item__c = pli.Id);
        insert timecard;
    }
}