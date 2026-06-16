/******************************************************************************
// File Name:       AssignmentTriggerHandlerTest
// Summary:         Test class for AssignmentTriggerHandler
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class AssignmentTriggerHandlerTest {
    @IsTest
    static void test() {
        Date dt = Date.today().toStartOfWeek();
        SFDC_Assignment__c assignment = new SFDC_Assignment__c(Start_Date__c = dt, End_Date__c = dt.addDays(13), Number_Of_Hours__c = 20);
        Test.startTest();
        insert assignment;
        Test.stopTest();
        List<Daily_Assignment__c> dailyAssignments = [select Id from Daily_Assignment__c where Assignment__c = :assignment.Id];
        System.assertEquals(10, dailyAssignments.size());
    }
}