public with sharing class NotificationBuilder {
	private final Task t;
	public NotificationBuilder(ApexPages.StandardController stdController){
		this.t = (Task)stdController.getRecord();
	}
	public pageReference Send(){
		string base= Url.getOrgDomainUrl().toExternalForm();
		string account='';
		string what='';
		string[] to=t.Email__c.Split(';');
		if(t.WhatId!=null){
			what=t.What.Name;
		}
		if(t.AccountId!=null){
			account=t.account.Name;
		}
		Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
		msg.setToAddresses(to);
		msg.setSubject('Task Notification: '+ t.Subject);
		msg.setHtmlBody('<p>Who: '+t.Who.Name+'</p><p>What: '+what+'</p><p>Account: '+account+'</p><p>Status: '+t.Status+'</p><p>Due Date: '
						+t.ActivityDate+'</p><p>Comments: '+t.Description+'</p><p>View Task <a href='+base+'/'+t.Id+
						'>Click Here</a></p>');
        if(!test.isRunningTest())
			Messaging.sendEmail(new Messaging.SingleEmailMessage[]{msg});
		PageReference taskPage = new ApexPages.StandardController(t).view();
        taskPage.setRedirect(true);
        return taskPage;
		
	}
	public pageReference Cancel(){
		PageReference taskPage = new ApexPages.StandardController(t).view();
        taskPage.setRedirect(true);
        return taskPage;
	}
}