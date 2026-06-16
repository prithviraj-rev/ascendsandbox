@isTest
public with sharing class caseViewHelperTest {
    @testSetup
    public static void setup() {
        list<account> a = new list<account>();
        a.add(new Account(name='Test1', BillingState='MD'));
		insert a;
        
        list<sfdc_projects__c> p = new list<sfdc_projects__c>();
        p.add(new sfdc_projects__c(name='test1', account__c=a[0].id, End_Date__c=date.today().addDays(-10)));
        insert p;

        list<case>c = new list<case>();
        c.add(new case(subject='test', description='test', accountId=a[0].Id, Project__c=p[0].Id, ownerId=userInfo.getUserId()));
        insert c;

        list<review__c> r = new list<review__c>();
        r.add(new review__c(project__c=p[0].Id, name='test'));
        insert r;
    }

    public static testmethod void testLoad(){
        map<string, list<string>> plo = caseViewHelper.getPicklistOptions();

        list<review__c> r = [select id from review__c];
        list<case> c = [select id from case];
        caseViewHelper.PageData pd = caseViewHelper.getCases(r[0].Id);

        caseViewHelper.caseReviewCheck(r[0].Id, c[0].Id );

        caseViewHelper.makeChatter(c[0].Id, 'Test post');
    }
}