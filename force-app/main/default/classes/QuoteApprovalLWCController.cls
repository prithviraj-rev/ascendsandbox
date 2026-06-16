public class QuoteApprovalLWCController {

    @InvocableMethod(label='Submit Quote for Approval')
    public static void submitQuoteForApproval(List<InputWrapper> input) {
        system.debug('Enter Method ');
        String flowApiName = 'Advance_Approvals';

        Map<String, Object> inputs = new Map<String, Object>();

        inputs.put('recordId', input[0].recordId);

        inputs.put('submitter', UserInfo.getUserId());

        inputs.put('submissionComments', input[0].submitterComments);
        system.debug('End Enter Method '+inputs);
        Flow.Interview myFlow = Flow.Interview.createInterview(flowApiName, inputs);
        
        myFlow.start();
    }

    public class InputWrapper {
        @InvocableVariable(label='Record ID' description='The ID of the record.' required=true)
        public Id recordId;

        @InvocableVariable(label='Comments ' description='Approval Comments.')
        public String submitterComments;
    }
}