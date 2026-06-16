/******************************************************************************
// Summary:         Service class that implements business logic related to the application emails
// Test Class:      EmailServiceTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public with sharing class EmailService 
{
    private static EmailService instance;

	/*********************** STATIC SECTION ***********************/

	public static EmailService getInstance()
	{
		if(instance == null) instance = new EmailService();
		return instance;
	}

	/*********************** PUBLIC SECTION ***********************/

    public void handleErrors(List<String> errors, String className, List<String> recipients) {
        handleErrors(errors, className, recipients, true);
    }

    public void handleErrors(List<String> errors, String className, List<String> recipients, Boolean notifyCurrentUser) {
        if(errors == null || errors.isEmpty()) return;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.saveAsActivity = false;

        if(notifyCurrentUser) {
            mail.setToAddresses(new List<String>{UserInfo.getUserId()});
            if(recipients != null) mail.setCCAddresses(recipients);
        }else {
            mail.setToAddresses(recipients);
        }

        mail.setSubject('Unexpected errors in the ' + className + '.');
        mail.setPlainTextBody(String.join(errors, '\r\n'));

        try{
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }catch(Exception ex) {
            System.debug(ex);
        }
    }
}