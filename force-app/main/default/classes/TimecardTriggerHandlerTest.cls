/******************************************************************************
// Summary:         Test class for TimecardTriggerHandler

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/27/2024 - created
*******************************************************************************/
@IsTest
private class TimecardTriggerHandlerTest {
    @IsTest
    static void testUpdateDailyAssignmentsPart1() {
        Account account = new Account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert account;

        Contact contact = new Contact(LastName='Test', accountId = account.Id, RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Resource').getRecordTypeId(), MailingCountry = 'US', MailingState = 'AL');
        insert contact;
        
        SFDC_Projects__c project = new SFDC_Projects__c(Account__c = account.Id);
        insert project;
                
        Project_Line_Item__c pli = new Project_Line_Item__c(Project__c = project.id);
        insert pli;
        
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(13), Number_Of_Hours__c = 20, Resource__c = contact.Id, Projects__c = project.Id);
        insert assignment;

        Daily_Assignment__c dailyAssignmentToday = new Daily_Assignment__c(Actual_Hours__c = 10, Assignment__c = assignment.Id, Daily_Date__c = Date.today());
        insert dailyAssignmentToday;

        Daily_Assignment__c dailyAssignmentYesturday = new Daily_Assignment__c(Actual_Hours__c = 10, Assignment__c = assignment.Id, Daily_Date__c = Date.today().addDays(-1));
        insert dailyAssignmentYesturday;

        SFDC_Timecard__c timeCard = new SFDC_Timecard__c(Assignment__c = assignment.Id, date__c = Date.today(), Project_Line_Item__c = pli.Id);
        insert timeCard;

        system.assertEquals(dailyAssignmentToday.Id, [Select Daily_Assignment__c From SFDC_Timecard__c Where Id = :timeCard.Id].get(0).Daily_Assignment__c);

        timeCard.Date__c = Date.today().addDays(-1);
        update timeCard;

        delete timeCard; 
    }
    
    @IsTest
    static void testUpdateDailyAssignmentsPart2() {
        Account account = new Account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert account;

        Contact contact = new Contact(LastName='Test', accountId = account.Id, RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Resource').getRecordTypeId(), MailingCountry = 'US', MailingState = 'AL');
        insert contact;
        
        SFDC_Projects__c project = new SFDC_Projects__c(Name=RPRFResourceService.DayOffProjects[0], Account__c = account.Id);
        insert project;
                
        Project_Line_Item__c pli = new Project_Line_Item__c(Project__c = project.id, Name = RPRFResourceService.PTO_PROJECT_NAME);
        insert pli;
        
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(13), Number_Of_Hours__c = 20, Resource__c = contact.Id, Projects__c = project.Id);
        insert assignment;
        
        SFDC_Timecard__c timeCard = new SFDC_Timecard__c(Assignment__c = assignment.Id, date__c = Date.today(), Project_Line_Item__c = pli.Id);
        insert timeCard;
        
        timeCard.Date__c = Date.today().addDays(-1);
        update timeCard;

        delete timeCard; 
    }
}