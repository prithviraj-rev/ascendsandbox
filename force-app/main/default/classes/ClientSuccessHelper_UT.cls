@isTest
public with sharing class ClientSuccessHelper_UT {
    @testsetup
    public static void setup(){
        
        User myself = [select id, firstname, lastname from user where id=:userinfo.getUserId()];
        list<account> accounts = new list<account>();
        accounts.add(new account(name='Ascend Technologies', BillingState = 'IL'));
        accounts.add(new account(name='Test', BillingState = 'IL'));
        insert accounts;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        Contact c = new Contact(LastName=myself.lastname, FirstName=myself.firstName, accountId=accounts[1].Id, RecordTypeId=lr[0].Id, Resource_User_Record__c = UserInfo.getUserId(), MailingCountry = 'US', MailingState = 'AL');
        insert c;
    }
    
    public static testmethod void testCSMChange(){
        list<account> acc = [select id from account where name='Test'];
        acc[0].ClientSuccessManager__c=userinfo.getUserId();
        update acc;
    }

    public static testmethod void testEnsureProjects(){
        ClientSuccessHelper.ensureProjects();
    }
}