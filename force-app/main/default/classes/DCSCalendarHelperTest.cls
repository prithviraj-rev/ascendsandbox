@IsTest
public class DCSCalendarHelperTest {

    private static testmethod void testCal(){
		Account a=new Account(name='DCSTestCo', BillingState = 'IL');
		insert a;
		date dToday = date.today();
		DCSCalendarHelper.aMonth thisMonth = new DCSCalendarHelper.aMonth(null);
		
		system.assertEquals(dToday.month(), thisMonth.month);
		system.assertEquals(string.valueOf(dToday.year()), thisMonth.year);
		thisMonth.getCategories(a.Id);
		string cj = DCSCalendarHelper.CalendarJSON(null);
		thisMonth.nextMonth();
		thisMonth.prevMonth();
	}
}