@IsTest
public class NotificationBuilderTest {

    public static testMethod void testNotificationBuilder() {
        Account a=new Account(Name='TESTAccount4NB', BillingState = 'IL');
        insert a;
        Contact c=new Contact(LastName='TESTContact4NB', AccountId=a.Id);
        insert c;
        Task t=new Task(WhoId=c.Id, WhatId=a.Id, Subject='TESTSubject', Status='Not Started', ActivityDate=system.today(), 
        				Description='TESTDescription',Email__c='james.jensen@lightindustries.com');
        insert t;
        ApexPages.StandardController sc = new ApexPages.StandardController(t);
        NotificationBuilder testNB = new NotificationBuilder(sc);
        PageReference pageRef = Page.NotificationBuilder;
        pageRef.getParameters().put('id', String.valueOf(t.Id));
        Test.setCurrentPage(pageRef);
        testNB.send();
        testNB.cancel();
    }
}