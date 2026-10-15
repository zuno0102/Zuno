using FluentValidation;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;

public class SetBusinessServiceQuestionsCommandValidator
    : AbstractValidator<SetBusinessServiceQuestionsCommand>
{
    /// <summary>
    /// Enough for any real job, and few enough that the booking form stays fillable on a phone.
    /// </summary>
    private const int MaxQuestions = 15;

    public SetBusinessServiceQuestionsCommandValidator()
    {
        RuleFor(x => x.ServiceId).NotEmpty();

        RuleFor(x => x.Questions)
            .Must(questions => questions.Count <= MaxQuestions)
            .WithMessage($"A service can ask at most {MaxQuestions} questions.");

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
