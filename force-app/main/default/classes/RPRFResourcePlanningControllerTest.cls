/******************************************************************************
// File Name:       RPRFResourcePlanningControllerTest
// Summary:         Test class for RPRFResourcePlanningController
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class RPRFResourcePlanningControllerTest {
    @TestSetup
    static void initData()
    {
        Account a = new account(name = 'Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name = 'Resource'];
        
        Contact c = new Contact(LastName = 'Test', FirstName = 'Test', accountId = a.Id, RecordTypeId = lr[0].Id, Employment_Type__c = '1099', MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Name = 'TestProj', Account__c = a.Id,Project_Stage__c='Active');     
        insert proj;
        
        Date startDate = Date.newInstance(2024, 11, 28).toStartOfWeek();
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(resource__c = c.Id, projects__c = proj.Id, Start_Date__c = startDate, End_Date__c = startDate.addDays(13), Number_Of_Hours__c = 60, Daily_Max__c = 10);
        insert assignment;
    }

    @IsTest
    static void test() {
        SFDC_Assignment__c assignment = [select Resource__c from SFDC_Assignment__c limit 1];
        SFDC_Projects__c proj = [select Id from SFDC_Projects__c limit 1];
        Contact c = [select Id from Contact limit 1];

        RPRFResourcePlanningController controller = new RPRFResourcePlanningController();
        Object config = controller.call('getConfiguration', new Map<String, Object>{'resourceId' => c.Id, 'projectId' => proj.Id});
        System.assertEquals(UserInfo.getName(), ((List<User>)((Map<String, Object>)config).get('currentUser'))[0].Name);
        System.assertEquals('Test Test', ((Contact)((Map<String, Object>)config).get('resource')).Name);
        System.assertEquals('TestProj', ((SFDC_Projects__c)((Map<String, Object>)config).get('project')).Name);

        System.assert(((Map<String, Object>)controller.call('getWeekConfiguration', new Map<String, Object>{'resourceId' => c.Id, 'date' => '2024-11-28'})).get('hasSubmitedForecast') == false);

        Task forecast = (Task)controller.call('submitForecast', new Map<String, Object>{'resourceId' => c.Id, 'date' => '2024-11-28'});
        System.assertEquals(Date.newInstance(2024, 11, 28), forecast.ActivityDate);
        System.assertEquals('Delivery Forecast', forecast.Purpose__c);
        System.assert(((Map<String, Object>)controller.call('getWeekConfiguration', new Map<String, Object>{'resourceId' => c.Id, 'date' => '2024-11-28'})).get('hasSubmitedForecast') == true);

        List<SFDC_Assignment__c> getAssignments = (List<SFDC_Assignment__c>)controller.call('getAssignments', new Map<String, Object>{'resourceId' => c.Id, 'projectId' => proj.Id, 'fromDate' => '2024-11-01', 'toDate' => '2024-11-30'});
        System.assertEquals(assignment.Id, getAssignments[0].Id);

        Map<String,Object> daysOf = (Map<String,Object>)controller.call('getDaysOffByResource', new Map<String, Object>{'resourceId' => c.Id, 'fromDate' => '2024-11-01', 'toDate' => '2024-11-30'});
        System.assert(daysOf.get('holidays') != null);
        System.assert(daysOf.get('pto') != null);
        
        daysOf = (Map<String,Object>)controller.call('getDaysOffByProject', new Map<String, Object>{'projectId' => proj.Id, 'fromDate' => '2024-11-01', 'toDate' => '2024-11-30'});
        System.assert(daysOf.get('holidays') != null);
        System.assert(daysOf.get('pto') != null);

        Daily_Assignment__c dailyAssignment = new Daily_Assignment__c(Name = 'test', Assignment__c = assignment.Id, Contact__c = assignment.Resource__c, Daily_Date__c = Date.today());
        insert(dailyAssignment);

        dailyAssignment.Name = 'test2';
        dailyAssignment = (Daily_Assignment__c)controller.call('saveDailyAssignment', new Map<String, Object>{'record' => dailyAssignment});
        System.assertEquals('test2', dailyAssignment.Name);

        Boolean exc = false;
        try {
            controller.call('invalid', null);
        }catch(Exception ex){
            exc = true;
            System.assertEquals('Invalid action name.', ex.getMessage());
        }
        System.assert(exc);
        
    }
}