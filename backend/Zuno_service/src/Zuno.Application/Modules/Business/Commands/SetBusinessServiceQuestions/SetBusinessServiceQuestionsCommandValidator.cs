using FluentValidation;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;

public class SetBusinessServiceQuestionsCommandValidator
    : AbstractValidator<SetBusinessServiceQuestionsCommand>
{
    public SetBusinessServiceQuestionsCommandValidator(IPlatformSettings platformSettings)
    {
        RuleFor(x => x.ServiceId).NotEmpty();

        // A platform setting: enough for any real job, few enough that the booking form stays
        // fillable on a phone.
        RuleFor(x => x.Questions)
            .Must(questions => questions.Count <= platformSettings.Current.ServiceMaxQuestions)
            .WithMessage(_ => $"A service can ask at most {platformSettings.Current.ServiceMaxQuestions} questions.");

        // A question with an id repeated twice would be edited twice and end up with whichever
        // came last, silently discarding one of the two the business typed.
        RuleFor(x => x.Questions)
            .Must(questions =>
            {
                var ids = questions.Where(q => q.Id.HasValue).Select(q => q.Id!.Value).ToList();
                return ids.Count == ids.Distinct().Count();
            })
            .WithMessage("The same question was sent twice.");

        RuleForEach(x => x.Questions).ChildRules(question =>
        {
            question.RuleFor(q => q.Prompt)
                .NotEmpty()
                .WithMessage("Give the question something to ask, or remove the row.")
                .MaximumLength(200);
        });
    }
}
