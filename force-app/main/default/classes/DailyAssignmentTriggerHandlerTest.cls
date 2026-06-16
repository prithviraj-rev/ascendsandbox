/******************************************************************************
// Summary:         Test class for DailyAssignmentTriggerHandler

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 06/11/2024 - created
*******************************************************************************/
@IsTest
private class DailyAssignmentTriggerHandlerTest {
    @IsTest
    static void test() {
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(13), Number_Of_Hours__c = 20);
        insert assignment;

        Daily_Assignment__c dailyAssignment = new Daily_Assignment__c(Actual_Hours__c = 10, Assignment__c = assignment.Id, Daily_Date__c = Date.today());
        insert dailyAssignment;

        try {
            dailyAssignment.Actual_Hours__c = 10;
            dailyAssignment.Projected_Hours__c = 5;
            update dailyAssignment;
        } catch (Exception ex) {}
    
        dailyAssignment = [select Projected_Hours__c, Locked__c, Lock_Reason__c from Daily_Assignment__c][0];
        System.assertEquals(5, dailyAssignment.Projected_Hours__c);
        System.assertEquals(true, dailyAssignment.Locked__c);
        System.assert(dailyAssignment.Lock_Reason__c != null);
  
        dailyAssignment = [select Locked__c from Daily_Assignment__c][0];
        dailyAssignment.Locked__c = false;
        update dailyAssignment;

        dailyAssignment = [select Actual_Hours__c, Locked__c, Lock_Reason__c from Daily_Assignment__c][0];
        System.assertEquals(false, dailyAssignment.Locked__c);
        System.assert(dailyAssignment.Lock_Reason__c == null);

        delete dailyAssignment;
        System.assertEquals(0, [select Id from Daily_Assignment__c].size());
    }

    @IsTest
    static void testUpdateTimeCards() {
        Account account = new account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert account;

        Contact contact = new Contact(LastName='Test', accountId = account.Id, RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Resource').getRecordTypeId(), MailingCountry = 'US', MailingState = 'AL');
        insert contact;
        
        SFDC_Projects__c project = new SFDC_Projects__c(Account__c = account.Id);
        insert project;
                
        Project_Line_Item__c pli = new Project_Line_Item__c(Project__c = project.id);
        insert pli;

        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(13), Number_Of_Hours__c = 20, Resource__c = contact.Id, Projects__c = project.Id);
        insert assignment;

        SFDC_Timecard__c timeCardToday = new SFDC_Timecard__c(Assignment__c = assignment.Id, date__c = Date.today(), Project_Line_Item__c = pli.Id);
        insert timeCardToday;

        SFDC_Timecard__c timeCardYesterday = new SFDC_Timecard__c(Assignment__c = assignment.Id, date__c = Date.today().addDays(-1), Project_Line_Item__c = pli.Id);
        insert timeCardYesterday;

        Daily_Assignment__c dailyAssignment = new Daily_Assignment__c(Actual_Hours__c = 10, Assignment__c = assignment.Id, Daily_Date__c = Date.today());
        insert dailyAssignment;

        system.assertEquals(dailyAssignment.Id, [Select Daily_Assignment__c From SFDC_Timecard__c Where Id = :timeCardToday.Id].get(0).Daily_Assignment__c);
        system.assertEquals(null, [Select Daily_Assignment__c From SFDC_Timecard__c Where Id = :timeCardYesterday.Id].get(0).Daily_Assignment__c);

        dailyAssignment.Daily_Date__c = Date.today().addDays(-1);
        update dailyAssignment;

        system.assertEquals(dailyAssignment.Id, [Select Daily_Assignment__c From SFDC_Timecard__c Where Id = :timeCardYesterday.Id].get(0).Daily_Assignment__c);
        system.assertEquals(null, [Select Daily_Assignment__c From SFDC_Timecard__c Where Id = :timeCardToday.Id].get(0).Daily_Assignment__c);

        delete dailyAssignment;
    }
}