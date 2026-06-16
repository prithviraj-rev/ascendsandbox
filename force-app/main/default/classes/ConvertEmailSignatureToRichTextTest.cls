@IsTest
public class ConvertEmailSignatureToRichTextTest {
	
    @IsTest
    static void convertToRichTextTestHappyPath() {
        String testSignature = '<table>\r\n<tr>\r\n<td>\r\n<img src="https://teamascend--pilot.sandbox.my.site.com/Contractors/resource/1774366839000/AscendLogo" width="100">\r\n</td>'
        + '\r\n<td>\r\n{{Your Name}}\r\n<b>{{Your Title}}</b>\r\nO: {{Your Phone Number}}\r\nE: {{Your Email}}\r\n<a href="{{Your LinkedIn Profile URL}}">Connect on LinkedIn</a>'
        + '\r\n</td>\r\n</tr>\r\n</table>';
        ConvertEmailSignatureToRichTextInvocable.Input input = new ConvertEmailSignatureToRichTextInvocable.Input();
        input.emailSignature = testSignature;
        List<ConvertEmailSignatureToRichTextInvocable.Input> inputs = new List<ConvertEmailSignatureToRichTextInvocable.Input>();
        inputs.add(input);
        List<ConvertEmailSignatureToRichTextInvocable.Output> outputs = ConvertEmailSignatureToRichTextInvocable.convertToRichText(inputs);
        Assert.isTrue(outputs[0].richTextSignature.contains('<br>'));
    }
    
    @IsTest
    static void convertToRichTextTestMissingSecondClosingTd() {
        String testSignature = '<table>\r\n<tr>\r\n<td>\r\n<img src="https://teamascend--pilot.sandbox.my.site.com/Contractors/resource/1774366839000/AscendLogo" width="100">\r\n</td>'
        + '\r\n<td>\r\n{{Your Name}}\r\n<b>{{Your Title}}</b>\r\nO: {{Your Phone Number}}\r\nE: {{Your Email}}\r\n<a href="{{Your LinkedIn Profile URL}}">Connect on LinkedIn</a>'
        + '\r\n\r\n</tr>\r\n</table>';
        ConvertEmailSignatureToRichTextInvocable.Input input = new ConvertEmailSignatureToRichTextInvocable.Input();
        input.emailSignature = testSignature;
        List<ConvertEmailSignatureToRichTextInvocable.Input> inputs = new List<ConvertEmailSignatureToRichTextInvocable.Input>();
        inputs.add(input);
        List<ConvertEmailSignatureToRichTextInvocable.Output> outputs = ConvertEmailSignatureToRichTextInvocable.convertToRichText(inputs);
        Assert.isFalse(outputs[0].richTextSignature.contains('<br>'));
    }
    
    @IsTest
    static void convertToRichTextTestOnly1Td() {
        String testSignature = '<table>\r\n<tr>\r\n\r\n<img src="https://teamascend--pilot.sandbox.my.site.com/Contractors/resource/1774366839000/AscendLogo" width="100">\r\n'
        + '\r\n<td>\r\n{{Your Name}}\r\n<b>{{Your Title}}</b>\r\nO: {{Your Phone Number}}\r\nE: {{Your Email}}\r\n<a href="{{Your LinkedIn Profile URL}}">Connect on LinkedIn</a>'
        + '\r\n</td>\r\n</tr>\r\n</table>';
        ConvertEmailSignatureToRichTextInvocable.Input input = new ConvertEmailSignatureToRichTextInvocable.Input();
        input.emailSignature = testSignature;
        List<ConvertEmailSignatureToRichTextInvocable.Input> inputs = new List<ConvertEmailSignatureToRichTextInvocable.Input>();
        inputs.add(input);
        List<ConvertEmailSignatureToRichTextInvocable.Output> outputs = ConvertEmailSignatureToRichTextInvocable.convertToRichText(inputs);
        Assert.isFalse(outputs[0].richTextSignature.contains('<br>'));
    }
    
    @IsTest
    static void convertToRichTextTestNoTd() {
        String testSignature = '<table>\r\n<tr>\r\n\r\n<img src="https://teamascend--pilot.sandbox.my.site.com/Contractors/resource/1774366839000/AscendLogo" width="100">\r\n'
        + '\r\n\r\n{{Your Name}}\r\n<b>{{Your Title}}</b>\r\nO: {{Your Phone Number}}\r\nE: {{Your Email}}\r\n<a href="{{Your LinkedIn Profile URL}}">Connect on LinkedIn</a>'
        + '\r\n\r\n</tr>\r\n</table>';
        ConvertEmailSignatureToRichTextInvocable.Input input = new ConvertEmailSignatureToRichTextInvocable.Input();
        input.emailSignature = testSignature;
        List<ConvertEmailSignatureToRichTextInvocable.Input> inputs = new List<ConvertEmailSignatureToRichTextInvocable.Input>();
        inputs.add(input);
        List<ConvertEmailSignatureToRichTextInvocable.Output> outputs = ConvertEmailSignatureToRichTextInvocable.convertToRichText(inputs);
        Assert.isFalse(outputs[0].richTextSignature.contains('<br>'));
    }
}