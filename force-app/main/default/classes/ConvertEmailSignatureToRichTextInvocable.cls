public class ConvertEmailSignatureToRichTextInvocable {
	@InvocableMethod(label='Convert Email Signature To Rich Text' description='Convert Email Signature To Rich Text')
    public static List<Output> convertToRichText(List<Input> inputs) {
        List<Output> outputs = new List<Output>();
        Output output;
        for (Input input : inputs) {
            output = new Output();
            String html = input.emailSignature;
            
            // Find the second <td>
            Integer firstTdClose = html.indexOf('</td>');
            if (firstTdClose == null || firstTdClose == -1) {
                output.richTextSignature = html;
                outputs.add(output);
                continue;
            }
            Integer secondTdStart = html.indexOf('<td>', firstTdClose);
            if (secondTdStart == null || secondTdStart == -1) {
                output.richTextSignature = html;
                outputs.add(output);
                continue;
            }
            Integer secondTdEnd = html.indexOf('</td>', secondTdStart);
            if (secondTdEnd == null || secondTdEnd == -1) {
                output.richTextSignature = html;
                outputs.add(output);
                continue;
            }
           
            String secondTdContent = html.substring(secondTdStart + 4, secondTdEnd);
            
            // Strip any remaining HTML tags
            String plainText = secondTdContent.trim();
            String newText = plainText.replace('\r\n','<br>').replace('\r','<br>').replace('\n','<br>');
            output.richTextSignature = html.replace(secondTdContent, newText);
            outputs.add(output);
        }
        return outputs;
    }
    
    public class Input {
        @InvocableVariable(label='Email Signature' description='Email Signature to Convert to Rich Text')
        public String emailSignature;
    }
    
    public class Output {
        @InvocableVariable(label='Rich Text Signature' description='Rich Text Version of Email Signature')
        public String richTextSignature;
    }
}