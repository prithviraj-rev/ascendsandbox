@IsTest
public class ConvertAcctHistValstoTextInvocableTest {
    
    @IsTest(seeAllData = true)
    static void convertAcctHistValstoText() {
        AccountHistory accHist = [SELECT Id, OldValue, NewValue FROM AccountHistory LIMIT 200][0];
        List<ConvertAcctHistValstoTextInvocable.Input> inputs = new List<ConvertAcctHistValstoTextInvocable.Input>();
        ConvertAcctHistValstoTextInvocable.Input input = new ConvertAcctHistValstoTextInvocable.Input();
        input.accHist = accHist;
        inputs.add(input);
        ConvertAcctHistValstoTextInvocable.Output output = ConvertAcctHistValstoTextInvocable.convertAcctHistValstoText(inputs)[0];
        
        if (accHist.NewValue != null) {
        	Assert.areEqual(String.valueOf(accHist.NewValue).replace(' 00:00:00', ''), output.newValueText);
        } else {
            Assert.areEqual('', output.newValueText);
        }
    }
}