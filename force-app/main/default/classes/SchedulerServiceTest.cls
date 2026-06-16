/******************************************************************************
// File Name:       SchedulerServiceTest
// Summary:         Test class for SchedulerService
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/

@IsTest
private class SchedulerServiceTest {
    @IsTest
    static void test() {
        new SchedulerService();
        SchedulerService.start('key', 'data', 'handlerName');
    }
}