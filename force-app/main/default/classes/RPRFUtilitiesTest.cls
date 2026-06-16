/******************************************************************************
// File Name:       RPRFUtilitiesTest
// Summary:         Test class for RPRFUtilities
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/

@IsTest
private class RPRFUtilitiesTest {
    @IsTest
    static void test() {
        Date dt = Date.newInstance(2024, 11, 28);
        System.assertEquals('2024-11-28', RPRFUtilities.formatDate(dt, 'yyyy-MM-dd'));
        System.assertEquals(4, RPRFUtilities.dayOfWeek(dt));
        System.assertEquals(false, RPRFUtilities.isWeekend(dt));

        Set<Date> weekends = RPRFUtilities.getWeekends(Date.newInstance(2024, 11, 28), Date.newInstance(2024, 11, 31));
        System.assertEquals(2, weekends.size());
        System.assertEquals(Date.newInstance(2024, 11, 30), RPRFUtilities.getMinDate(weekends));
        System.assertEquals(Date.newInstance(2024, 11, 31), RPRFUtilities.getMaxDate(weekends));
        
        Boolean except = false;
        try {
            update new User();
        }catch(Exception ex){
            except = true;
            System.assertEquals('Id not specified in an update call', RPRFUtilities.getExceptionMessage(ex));
        }
        System.assert(except);

        System.assertEquals(true, (Boolean)RPRFUtilities.stringToObject('true', Schema.DisplayType.Boolean));
        System.assertEquals(123.0, (Double)RPRFUtilities.stringToObject('123', Schema.DisplayType.Double));
        System.assertEquals(123, (Integer)RPRFUtilities.stringToObject('123', Schema.DisplayType.Integer));
        System.assertEquals(dt, (Date)RPRFUtilities.stringToObject('2024-11-28', Schema.DisplayType.Date));
        System.assertEquals(Datetime.newInstanceGmt(2024, 11, 28, 11, 46, 0), (DateTime)RPRFUtilities.stringToObject('2024-11-28T11:46:00Z', Schema.DisplayType.DateTime));
        //System.assertEquals(Time.newInstance(11, 46, 0, 0), (Time)RPRFUtilities.stringToObject('11:46 AM', Schema.DisplayType.Time));
        System.assertEquals(Time.newInstance(11, 46, 0, 0), (Time)RPRFUtilities.stringToObject('11:46', Schema.DisplayType.Time));
        System.assertEquals((ID)UserInfo.getUserId(), (ID)RPRFUtilities.stringToObject(UserInfo.getUserId(), Schema.DisplayType.ID));
        System.assertEquals(null, RPRFUtilities.stringToObject(null, Schema.DisplayType.BASE64));
        System.assertEquals(null, RPRFUtilities.stringToObject(null, Schema.DisplayType.ADDRESS));


        RPRFUtilities.addToCache('key', 'value');
        System.assertEquals('value', RPRFUtilities.extractFromCache('key'));
        System.assertEquals(true, RPRFUtilities.containsInCache('key'));
        RPRFUtilities.removeFromCache('key');
        System.assertEquals(false, RPRFUtilities.containsInCache('key'));
        RPRFUtilities.addToCache('key', 'value');
        RPRFUtilities.clearCache();
        System.assertEquals(false, RPRFUtilities.containsInCache('key'));
    }
}