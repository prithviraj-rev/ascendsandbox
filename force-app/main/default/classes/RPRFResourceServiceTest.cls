/******************************************************************************
// Summary:         Test class for RPRFResourceService

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 06/12/2024 - created
Martin Ryder - 06/02/2026 - Added Bypass validations permission to running user.
*******************************************************************************/
@IsTest
private class RPRFResourceServiceTest {
    @IsTest
    static void test() {

        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
        User u = new User(Alias = 'holiday', Email='testholiday@testorg.com', 
                          EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
                          LocaleSidKey='en_US', ProfileId = p.Id, ManagerId = UserInfo.getUserId(),
                          TimeZoneSidKey='America/Los_Angeles', UserName='testholiday@testorg.com');
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'BypassValidationRules'];
        PermissionSetAssignment psa = new PermissionSetAssignment(
        AssigneeId = u.id,
        PermissionSetId = ps.Id);
        insert psa;
        Test.startTest();
        //setup
        System.runAs(u) {

            Account a = new account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
            insert a;

            list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name = 'Resource'];      
            Contact c = new Contact(LastName = 'Test', FirstName = 'Test', accountId = a.Id, RecordTypeId = lr[0].Id, Employment_Type__c = '1099', MailingCountry = 'US', MailingState = 'AL');
            insert c;

            SFDC_Projects__c proj = new SFDC_Projects__c(Account__c = a.Id, Project_Stage__c='Active', Name = RPRFResourceService.DayOffProjects[0]);
            insert proj;

            Project_Line_Item__c pli = new Project_Line_Item__c(Project__c = proj.id, Name = RPRFResourceService.DayOffProjectsLines[0]);
            insert pli;

            Date startDate = system.today().toStartOfWeek();
            SFDC_Assignment__c assignment = new SFDC_Assignment__c(resource__c = c.Id, projects__c = proj.Id, Start_Date__c = startDate, End_Date__c = startDate.addDays(13), Number_Of_Hours__c = 60, Daily_Max__c = 10);
            insert assignment;

            RPRFResourceService service = RPRFResourceService.getInstance();
            List<Project_Line_Item__c> projectLineItem = service.getHolidaysProjectLines();
            System.assertEquals(pli.Id, projectLineItem[0].Id);

            SFDC_Timecard__c timecard = new SFDC_Timecard__c(Date__c = startDate.addDays(2), Hours__c = 8, Assignment__c = assignment.Id, Project_Line_Item__c = pli.Id);
            insert timecard;

            Map<ID, Set<Date>> unavailabeDates = service.getUnavailabeDates(new Set<ID>{c.Id}, startDate, startDate.addDays(3));
            System.assertEquals(1, unavailabeDates.get(c.Id).size());
            System.assertEquals(startDate.addDays(2), new List<Date>(unavailabeDates.get(c.Id))[0]);
            
            System.assert(service.getHolidays(new Set<ID>{c.Id}, startDate, startDate.addDays(3)) != null);
            System.assert(service.getPTOs(new Set<ID>{c.Id}, startDate, startDate.addDays(3)) != null);
        }
    }
}