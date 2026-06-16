public without sharing class ConvertAcctHistValstoTextInvocable {
	
    @InvocableMethod(label='Convert Account History Values To Text' description='Convert Account History Values To Text')
    public static List<Output> convertAcctHistValstoText(List<Input> inputs) {
        List<Output> outputs = new List<Output>();
        Output output;
        for (Input input : inputs) {
            output = new Output();
            output.oldValueText = input.accHist.OldValue != null ? String.valueOf(input.accHist.OldValue).replace(' 00:00:00', '') : '';
            output.newValueText = input.accHist.NewValue != null ? String.valueOf(input.accHist.NewValue).replace(' 00:00:00', '') : '';
            outputs.add(output);
        }
        return outputs;
    }
    
    public class Input {
        @InvocableVariable(label='Account History Record' description='Account History Record')
        public AccountHistory accHist;
    }
    
    public class Output {
        @InvocableVariable(label='Old Value Text' description='Text Value of Account History\'s Old Value Field')
        public String oldValueText;
        
        @InvocableVariable(label='New Value Text' description='Text Value of Account History\'s New Value Field')
        public String newValueText;
    }
}