/******************************************************************************
// File Name:       EmailServiceTest
// Summary:         Test class for EmailService
// Created On:      11/28/2024

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 11/28/2024 - created
*******************************************************************************/
@IsTest
private class EmailServiceTest {
    @IsTest
    static void test() {
        EmailService servcie = EmailService.getInstance();
        servcie.handleErrors(new List<String>{'e1'}, 'EmailServiceTest', new List<String>{'test@gmail.com'});
        servcie.handleErrors(new List<String>{'e1'}, 'EmailServiceTest', new List<String>{'test@gmail.com'}, false);
    }
}