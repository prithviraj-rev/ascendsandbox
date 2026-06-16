/******************************************************************************
// Summary:         Test class for RPRFDailyAssignmentsBuilderController

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 06/12/2024 - created
*******************************************************************************/
@IsTest
private class RPRFDailyAssignmentBuilderControllerTest {
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
        
        Date startDate = System.today().toStartOfWeek();
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Resource__c = c.Id, Projects__c = proj.Id, Start_Date__c = startDate, End_Date__c = startDate.addDays(13), Number_Of_Hours__c = 60, Daily_Max__c = 10);
        insert assignment;
    }

    @IsTest
    static void test() {
        SFDC_Assignment__c assignment = [select Id from SFDC_Assignment__c limit 1];

        RPRFDailyAssignmentsBuilderController controller = new RPRFDailyAssignmentsBuilderController();
        assignment = (SFDC_Assignment__c)controller.call('getAssignment', new Map<String, Object>{'assignmentId' => assignment.Id});
        System.assertEquals(60, assignment.Number_Of_Hours__c);
        System.assertEquals(System.today().toStartOfWeek(), assignment.Start_Date__c);
        System.assertEquals(10, [select Id from Daily_Assignment__c].size());

        RPRFAssignmentService service = RPRFAssignmentService.getInstance();
        service.clearDailyAssignments(new Set<Date>{date.today()});
        System.assertEquals(9, [select Id from Daily_Assignment__c].size());

        controller.call('rebuildDailyAssignments', new Map<String, Object>{'assignmentId' => assignment.Id, 'dailyAssignments' => false, 'actualHours' => true, 'projectedHours' => true});
        controller.call('rebuildDailyAssignments', new Map<String, Object>{'assignmentId' => assignment.Id, 'dailyAssignments' => true, 'actualHours' => false, 'projectedHours' => false});

        try {
            controller.call('unknownAction', null);
        } catch (Exception ignore) {}
    }
}