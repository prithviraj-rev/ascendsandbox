import auraInvoke from '@salesforce/apex/BaseController.auraInvoke';

const handleAuraInvokeResult = (result) => {
    const callResult = new Promise(
        (resolve, reject) => {
            result.error ? reject(result.error) : resolve(result)
        }
    );
    return callResult;
};

class Apex {
    static invoke = async (handler, action, params = {}) => {
        const result = await auraInvoke({
            handlerName: handler,
            actionName: action,
            params: params
        });

        return handleAuraInvokeResult(result);
    };
}

export default Apex;