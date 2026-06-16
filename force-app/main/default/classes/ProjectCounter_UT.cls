@isTest
public class ProjectCounter_UT {
	@testsetup
    public static void setup(){
        list<account> a = new list<account>();
        a.add(new Account(name='Test1', BillingState = 'IL'));
        a.add(new Account(name='Test2', BillingState = 'IL'));
		insert a;
        
        list<sfdc_projects__c> p = new list<sfdc_projects__c>();
        p.add(new sfdc_projects__c(name='test', account__c=a[0].id, End_Date__c=date.today().addDays(-750)));
        p.add(new sfdc_projects__c(name='test2', account__c=a[1].id, End_Date__c=date.today().addDays(-10)));

        insert p;
    }
    
    public static testmethod void testProjectcounter(){
        test.startTest();
        ProjectCounterSchedule pcs = new ProjectCounterSchedule();
		String sch = '0 0 23 * * ?'; 
        system.schedule('Test ProjectCounter', sch, pcs); 
        Test.stopTest(); 
        
    }
}