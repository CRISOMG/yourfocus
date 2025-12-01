export const useSuccessErrorToast = () => {
  const toast = useToast();

  function addSuccessToast({
    title,
    description,
  }: {
    title: string;
    description: string;
  }) {
    toast.add({ title, description, color: "success" });
  }

  function addErrorToast({
    title,
    description,
  }: {
    title: string;
    description: string;
  }) {
    toast.add({ title, description, color: "error" });
  }

  return {
    addSuccessToast,
    addErrorToast,
  };
};
