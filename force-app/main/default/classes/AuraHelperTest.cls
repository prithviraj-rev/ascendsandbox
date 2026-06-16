/******************************************************************************
// File Name:       AuraHelperTest
// Summary:         test class for AuraHelper.cls
// Created On:      03/18/2020
// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 03/18/2020  - New Apex class created
*******************************************************************************/
@IsTest
private class AuraHelperTest {
    @IsTest static void testAuraResponse() {
        AuraHelper.Response response;

        String testResponseData = 'some data';
        response = new AuraHelper.Response(testResponseData);
        System.assert(response.success == true);
        System.assert((String) response.result == testResponseData);

        String message = 'invalid request';
        response = new AuraHelper.Response(false, message);
        System.assert(response.success == false);
        System.assert(response.message == message);

        try {
            Integer i = 1 / 0;
        }
        catch(Exception ex){
            response = new AuraHelper.Response(ex);
        }
        System.assert(response.success == false);
        System.assert(response.technicalData != null);
    }

    @IsTest static void testAuraPicklistOption() {
        Schema.DescribeFieldResult familyFieldDescribeResult = Product2.Family.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = familyFieldDescribeResult.getPicklistValues();

        if (picklistEntries.size() > 0){
            AuraHelper.PicklistOption po = new AuraHelper.PicklistOption(picklistEntries.get(0));

            System.assert(po.value == picklistEntries.get(0).getValue());
            System.assert(po.label == picklistEntries.get(0).getLabel());
        }
    }
}