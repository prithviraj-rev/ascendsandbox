/******************************************************************************
// Summary:         Test class for RPRFAssignmentService

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 06/12/2024 - created
Martin Ryder - 06/02/2026 - Added Bypass validations permission to running user.
*******************************************************************************/
@IsTest
private class RPRFAssignmentServiceTest {
    @TestSetup
    static void initData()
    {

        

        Account a = new account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name = 'Resource'];
        
        Contact c = new Contact(LastName = 'Test', FirstName = 'Test', accountId = a.Id, RecordTypeId = lr[0].Id, Employment_Type__c = '1099', MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c = a.Id,Project_Stage__c='Active');     
        insert proj;
        
        Date startDate = system.today().toStartOfWeek();
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(resource__c = c.Id, projects__c = proj.Id, Start_Date__c = startDate, End_Date__c = startDate.addDays(13), Number_Of_Hours__c = 60, Daily_Max__c = 10);
        insert assignment;
        
        Project_Line_Item__c pli = new Project_Line_Item__c();
        pli.Project__c = proj.id;
        insert pli;
    }

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
            Account a = [select Id from Account limit 1];
            Contact c = [select Id from Contact limit 1];
            SFDC_Projects__c proj = [select Id from SFDC_Projects__c limit 1];
            SFDC_Assignment__c assignment = [select Id from SFDC_Assignment__c limit 1];
            Project_Line_Item__c pli = [select Id from Project_Line_Item__c limit 1];
            Date startDate = system.today().toStartOfWeek();
            Date endDate = startDate.addDays(6);

            RPRFAssignmentService service = RPRFAssignmentService.getInstance();
            assignment = service.getAssignment(assignment.Id);
            service.getAssignments(assignment.Id, proj.Id, startDate, endDate);
            service.getDailyAssignments(c.Id, proj.Id, startDate, endDate);
            service.getDailyAssignmentsByResource(c.Id, startDate, endDate);
            service.getDailyAssignmentsByProject(proj.Id, startDate, endDate);
            
            Timesheet__c timesheet = new Timesheet__c(Start_Date__c = startDate, End_Date__c = endDate, Resource__c = c.Id, Distinct_Id__c = string.valueOf(c.Id).left(15) + string.valueOf(startDate));
            insert timesheet;
            SFDC_Timecard__c timecard = new SFDC_Timecard__c(Date__c = startDate.addDays(2), Hours__c = 30, Assignment__c = assignment.Id, Timesheet__c = timesheet.Id, Project_Line_Item__c = pli.Id);
            insert timecard;

            List<SFDC_Timecard__c> timecards = service.getAssignmentsTimecards(new List<ID>{assignment.Id}, null, null);
            System.assertEquals(1, timecards.size());
            System.assertEquals(timecard.Id, timecards[0].Id);

            Map<ID, Map<Date, Decimal>> actualDates = service.getAssignmentsActualDates(new List<ID>{assignment.Id});
            System.assertEquals(0, actualDates.size());

            List<Daily_Assignment__c> dailyAssignments = service.getDailyAssignments(assignment.Id, null, null);
            System.assertEquals(10, dailyAssignments.size());

            service.clearDailyAssignments(assignment);
            service.clearDailyAssignments(new Set<Date>{date.today()});
            System.assertEquals(0, [select id from Daily_Assignment__c].size());

            service.createResourceDailyAssignments(new Map<ID, Set<Date>>{c.Id => new Set<Date>{Date.today()}});
            dailyAssignments = [select Daily_Date__c from Daily_Assignment__c];
            System.assertEquals(1, dailyAssignments.size());
            System.assertEquals(Date.today(), dailyAssignments[0].Daily_Date__c);

            service.clearDailyAssignments(new Map<ID, Set<Date>>{c.Id => new Set<Date>{Date.today()}});
            System.assertEquals(0, [select Daily_Date__c from Daily_Assignment__c].size());
        }
    }

    @IsTest
    static void recalculationTest() {
        Account a = [select Id from Account limit 1];
        Contact c = [select Id from Contact limit 1];
        SFDC_Projects__c proj = [select Id from SFDC_Projects__c limit 1];
        SFDC_Assignment__c assignment = [select Id from SFDC_Assignment__c limit 1];
        Project_Line_Item__c pli = [select Id from Project_Line_Item__c limit 1];

        RPRFAssignmentService service = RPRFAssignmentService.getInstance();
        Date startDate = system.today().toStartOfWeek();
        Date endDate = startDate.addDays(6);
        Timesheet__c timesheet = new Timesheet__c(Start_Date__c = startDate, End_Date__c = endDate, Resource__c = c.Id, Distinct_Id__c = string.valueOf(c.Id).left(15) + string.valueOf(startDate));
        insert timesheet;
        SFDC_Timecard__c timecard = new SFDC_Timecard__c(Date__c = startDate.addDays(2), Hours__c = 30, Assignment__c = assignment.Id, Timesheet__c = timesheet.Id, Project_Line_Item__c = pli.Id);
        insert timecard;

        service.recalculateDailyAssignments(assignment.Id, false, false);
        service.recalculateActualHours(assignment.Id);
        service.recalculateProjectedHours(assignment.Id);
        List<Daily_Assignment__c> dailyAssignments = service.getDailyAssignments(assignment.Id, null, null);
        System.assertEquals(10, dailyAssignments.size());

        timesheet.Status__c = 'Approved';
        AbstractTrigger.Disabled = true;
        update timesheet;
        AbstractTrigger.Disabled = false;
        service.processApprovedTimesheets(new List<Timesheet__c>{timesheet});

        system.debug(assignment);
        Map<ID, Map<Date, Decimal>> actualDates = service.getAssignmentsActualDates(new List<ID>{assignment.Id});
        system.debug(actualDates);
//        System.assertEquals(30, actualDates.get(assignment.Id).get(startDate.addDays(2)));

        Test.startTest();

        list<SFDC_Assignment__c> assignmentsbyresource = service.getAssignmentsByResourcesAndDates(new map<Id, set<date>>{c.id=>new set<date>{startDate, enddate}});

        service.call('recalculateDailyAssignments', new Map<String, Object>{'data' => new List<ID>{assignment.Id}});
        service.call('createResourceDailyAssignments', new Map<String, Object>{'data' => new Map<ID, Set<Date>>{c.Id => new Set<Date>{Date.today()}}});
        service.call('recalculateProjectedHours', new Map<String, Object>{'data' => new List<ID>{assignment.Id}});
        try {
            service.call('unknownAction', null);
        } catch (Exception ignore) {}

    }
}