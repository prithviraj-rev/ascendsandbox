/******************************************************************************
// File Name:       SObjectServiceTest
// Summary:         Test class for SObjectService
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/

@IsTest
private class SObjectServiceTest {
    @IsTest
    static void test() {
        SObjectService service = SObjectService.getInstance();
        SObject user = service.loadSObject(UserInfo.getUserId());
        System.assertEquals(UserInfo.getUserId(), user.Id);

        user = service.loadSObject(UserInfo.getUserId(), new Set<String>{'FirstName'});
        System.assertEquals(UserInfo.getFirstName(), ((User)user).FirstName);

        List<SObject> users = service.loadSObjects('select Id from User where Id = \'' + UserInfo.getUserId() + '\'');
        System.assertEquals(UserInfo.getUserId(), users[0].Id);

        users = service.loadSObjectsWithOffset('select Id from User where Id = \'' + UserInfo.getUserId() + '\'');
        System.assertEquals(UserInfo.getUserId(), users[0].Id);

        users = service.loadSObjects('User', null, 'Id=\'' + UserInfo.getUserId() + '\'', null, null, null, null);
        System.assertEquals(UserInfo.getUserId(), users[0].Id);
    }
}