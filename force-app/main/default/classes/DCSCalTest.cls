@isTest
public class DCSCalTest {

    private static testmethod void testCal(){
		Account a=new Account(name='DCSTestCo', BillingState = 'IL');
		insert a;
		date dToday = date.today();
		DCSCal thisMonth = new DCSCal();
		
		thisMonth.target=a.Id;
		pagereference n = thisMonth.NextMonth();
		pagereference p = thisMonth.PrevMonth();
	}
}