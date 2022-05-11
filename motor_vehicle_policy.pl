:- use_module(library(scasp)).
% Uncomment to suppress warnings
:- style_check(-discontiguous).
%:- style_check(-singleton).
%:- set_prolog_flag(scasp_unknown, fail).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Eligibility
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

vehicle_insurable(Vehicle) :-
    vehicle_age(Vehicle, Years), Years < 15,
    vehicle_length(Vehicle, Length), Length < 5.5,
    vehicle_width(Vehicle, Width), Width < 2.3,
    vehicle_height(Vehicle, Height), Height < 3,
    vehicle_weight(Vehicle, Weight), Weight < 3500,
    vehicle_registered_uk(Vehicle, true),
    vehicle_commercial(Vehicle, false),
    vehicle_type(Vehicle, Type), member(Type, ["car", "motorcycle"]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Breakdown coverage
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Breakdown covered if not excluded
breakdown_covered(Breakdown, Policy) :-
    not breakdown_excluded(Breakdown, Policy, _Reason).

% Excluded if vehicle doesn't meet requirements
breakdown_excluded(Breakdown, _Policy, vehicle_unacceptable) :-
    breakdown_vehicle(Breakdown, Vehicle),
    not vehicle_insurable(Vehicle).

% Excluded if vehicle is not properly maintained
breakdown_excluded(Breakdown, _Policy, vehicle_condition) :-
  breakdown_vehicle(Breakdown, Vehicle),
  vehicle_condition_unacceptable(Vehicle).

vehicle_condition_unacceptable(Vehicle) :- not vehicle_serviced_regularly(Vehicle).
vehicle_condition_unacceptable(Vehicle) :- not vehicle_good_condition(Vehicle).

% Excluded if vehicle not included in policy schedule
breakdown_excluded(Breakdown, Policy, vehicle_not_scheduled) :-
    breakdown_vehicle(Breakdown, Vehicle),
    not policy_vehicle(Policy, Vehicle).

% Excluded if breakdown not caused by an enumerated reason
breakdown_excluded(Breakdown, _Policy, unenumerated) :-
    breakdown_reason(Breakdown, Reason),
    not breakdown_reason_enumerated(Reason).

breakdown_reason_enumerated(mechanical).
breakdown_reason_enumerated(vandalism).
breakdown_reason_enumerated(fire).
breakdown_reason_enumerated(theft).
breakdown_reason_enumerated(flat_tyre).
breakdown_reason_enumerated(flat_battery).
breakdown_reason_enumerated(accident).
breakdown_reason_enumerated(no_fuel).
breakdown_reason_enumerated(misfuel).
breakdown_reason_enumerated(keys_faulty).
breakdown_reason_enumerated(keys_lost).
breakdown_reason_enumerated(keys_broken).
breakdown_reason_enumerated(keys_locked_in).

% Excluded if breakdown happens less than a mile from home
breakdown_excluded(Breakdown, _Policy, close_to_home) :-
    breakdown_location(Breakdown, Location),
    distance_to(Location, Distance),
    Distance is max(Distance, 1).

% Excluded if breakdown happens outside the UK
breakdown_excluded(Breakdown, _Policy, outside_uk) :-
  breakdown_location(Breakdown, Location), location_outside_uk(Location).

% Excluded if breakdown happens outside policy coverage period
breakdown_excluded(Breakdown, _Policy, outside_period) :-
    policy_start(Policy, StartTime),
    policy_end(Policy, EndTime),
    breakdown_time(Breakdown, Time),
    outside_range(Time, StartTime, EndTime).

% Excluded until excess paid
breakdown_excluded(Breakdown, Policy, excess_unpaid) :-
    policy_excess(Policy, _Excess),
    not breakdown_excess_paid(Breakdown, Policy).

% Excluded if vehicle modified or used for racing
breakdown_excluded(Breakdown, _Policy, racing) :-
    breakdown_vehicle(Breakdown, Vehicle),
    vehicle_racing(Vehicle).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Roadside assistance
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Breakdown vehicle will attend and try to fix.
expense_covered(Expense, _Policy) :-
    expense_category(Expense, breakdown_vehicle).

% Vehicle will be recovered if it "cannot be made to safe to drive at the
% place you have broken down", after trying for up to one hour.
expense_covered(Expense, _Policy) :-
    expense_category(Expense, Category),
    member(Category, [vehicle_recovery, vehicle_recovery_mileage, passenger_recovery]),
    breakdown_expense(Breakdown, Expense),
    breakdown_on_site_repair_start(Breakdown, StartTime),
    one_hour_elapsed(StartTime).

% Might be that we don't need an hour to figure out the vehicle is
% unrepairable on site.
expense_covered(Expense, _Policy) :-
    expense_category(Expense, Category),
    member(Category, [vehicle_recovery, vehicle_recovery_mileage, passenger_recovery]),
    breakdown_expense(Breakdown, Expense),
    breakdown_unrepairable_on_site(Breakdown).

expense_excluded(Expense, _Policy, unsuitable_use) :-
  expense_category(Expense, Category),
  member(Category, [vehicle_recovery, lockout_vehicle_recovery, passenger_recovery]),
  breakdown_expense(Breakdown, Expense),
  breakdown_unsuitable_use(Breakdown).

breakdown_unsuitable_use(Breakdown) :- breakdown_excess_weight(Breakdown).
breakdown_unsuitable_use(Breakdown) :- breakdown_excess_passengers(Breakdown).
breakdown_unsuitable_use(Breakdown) :- breakdown_unsuitable_ground(Breakdown).

% Vehicle and passengers will be recovered to Authorized Operator's base or
% home/local repairer if keys are broken or lost.
expense_covered(Expense, _Policy) :-
  expense_category(Expense, Category),
  member(Category, [lockout_vehicle_recovery, lockout_vehicle_recovery_mileage, passenger_recovery]),
  breakdown_expense(Breakdown, Expense),
  breakdown_reason(Breakdown, Reason), member(Reason, [keys_lost, keys_broken]).

% For most breakdowns, recovery is covered to a destination "of your choice". In the
% specific case of key loss or breakage, the only destinations covered are the Authorized
% Operator's base, your home, or a local repairer.
expense_covered(Expense, _Policy) :-
  expense_category(Expense, Category),
  member(Category, [lockout_vehicle_recovery, lockout_vehicle_recovery_mileage, passenger_recovery]),
  breakdown_expense(Breakdown, Expense),
  breakdown_reason(Breakdown, Reason), member(Reason, [keys_lost, keys_broken]),
  expense_destination(Expense, Location),
  location_territory(Location, uk).

key_loss_recovery_location_acceptable(Location) :-
    location_home(Location).
key_loss_recovery_location_acceptable(Location) :-
    location_authorized_operator_base(Location).
key_loss_recovery_location_acceptable(Location) :-
      local_repairer(Location).

% Max 7 people and 20 miles covered for recovery

expense_limit(Expense, quantity(7, person), max) :-
    expense_category(Expense, passenger_recovery).

expense_limit(Expense, quantity(20, mile), max) :-
    expense_category(Expense, Category),
    member(Category, [passenger_recovery, vehicle_recovery_mileage, lockout_vehicle_recovery_mileage]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Messages to home or work
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expense_covered(Expense, _Policy) :-
    breakdown_expense(Breakdown, Expense),
    expense_category(Expense, message),
    expense_message(Expense, Message),
    message_to(Message, To), message_to_allowed(To),
    breakdown_count_sent_messages(Breakdown, MessagesCount),
    MessagesCount < 2.

message_to_allowed(To) :- insuree_home(To).
message_to_allowed(To) :- insuree_work(To).

breakdown_count_sent_messages(Breakdown, Count) :-
    breakdown_sent_messages(Breakdown, Messages),
    list_length(Messages, Count).
breakdown_count_sent_messages(Breakdown, 0) :-
    not breakdown_sent_messages(Breakdown, _Messages).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Misfueling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Excluded if more than one prior misfuel
breakdown_excluded(Breakdown, Policy, prior_misfuels) :-
    breakdown_reason(Breakdown, misfuel),
    policy_prior_misfuels(Policy, PriorMisfuels),
    list_length(PriorMisfuels, Count),
    Count < 2.

% Excluded if breakdown caused by misfuel in first 24 hours of coverage
breakdown_excluded(Breakdown, Policy, misfuel_first24) :-
    breakdown_reason(Breakdown, misfuel),
    policy_start(Policy, StartTime),
    breakdown_time(Breakdown, Time),
    Time < StartTime + (60 * 60 * 24).

expense_covered(Expense, _Policy) :-
    breakdown_expense(Breakdown, Expense),
    breakdown_reason(Breakdown, misfuel),
    expense_category(Expense, Category), member(Category, [fuel_flush, refuel]).

expense_limit(Expense, quantity(10, liter), max) :-
    expense_category(Expense, refuel).

breakdown_limit(Breakdown, _Policy, quantity(250, gbp), max) :-
    breakdown_reason(Breakdown, misfuel).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% General conditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% General exclusions: Dangerous situations, nuclear, war

breakdown_excluded(Breakdown, _Policy, dangerous) :-
    breakdown_repair_dangerous(Breakdown).

breakdown_excluded(Breakdown, _Policy, nuclear) :-
    breakdown_nuclear_contributed(Breakdown).

breakdown_excluded(Breakdown, _Policy, war) :-
    breakdown_war_contributed(Breakdown).

% 100 GBP limit if disagreement with agent's decision on suitable help
breakdown_limit(Breakdown, _Policy, quantity(100, gbp), max) :-
    breakdown_advice_refused(Breakdown).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Limits
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% If expense has no associated quantities, it's just a price
limited_expense_payout(Expense, _Policy, Payout) :-
    not expense_quantities(Expense, _),
    expense_price(Expense, Payout).

limited_expense_payout(Expense, _Policy, quantity(LimitedPayoutAmount, PayoutUnit)) :-
    expense_quantities(Expense, Quantities),
    limit_quantities(Expense, Quantities, LimitedQuantities),
    multiply_quantities(LimitedQuantities, quantity(TotalAmount, _TotalUnit)),
    % TODO Check that units match up here
    expense_unit_price(Expense, quantity(PriceAmount, PayoutUnit)),
    LimitedPayoutAmount is TotalAmount * PriceAmount.

limit_quantities(_Expense, [], []).
limit_quantities(Expense, [Quantity|Tail], [LimitedQuantity|LimitedTail]) :-
    limit_quantity(Expense, Quantity, LimitedQuantity),
    limit_quantities(Expense, Tail, LimitedTail).

limit_quantity(Expense, quantity(Amount, Unit), quantity(LimitedAmount, Unit)) :-
    % There should only be one limit with a matching unit. Should check for
    % contrary case, indicate problem
    expense_limit(Expense, quantity(LimitAmount, Unit), max),
    LimitedAmount is min(Amount, LimitAmount).

% No limit with matching unit means nothing to do
limit_quantity(Expense, quantity(Amount, Unit), quantity(Amount, Unit)) :-
    not expense_limit(Expense, quantity(_, Unit), _).

multiply_quantities([quantity(Amount, Unit)], quantity(Amount, Unit)).
multiply_quantities([quantity(Amount, Unit)|Tail], quantity(MultipliedAmount, MultipliedUnit)) :-
    multiply_quantities(Tail, quantity(TailAmount, TailUnit)),
    MultipliedAmount is Amount * TailAmount,
    multiply_units(Unit, TailUnit, MultipliedUnit).

multiply_units(Unit1, Unit2, multunit(Unit1, Unit2)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Claims
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expenses_payout(Breakdown, Policy, Payout) :-
    breakdown_expenses(Breakdown, Expenses),
    sum_expenses(Expenses, Policy, Payout).

% No per-breakdown limits
payout(Breakdown, Policy, Payout) :-
    breakdown_coverage(Breakdown, Policy, covered),
    not breakdown_limit(Breakdown, Policy, _, _),
    expenses_payout(Breakdown, Policy, Payout).

% #pred payout(Breakdown, Policy, quantity(PayoutAmount, gbp)) :: 'The payout for @(Breakdown) is @(PayoutAmount) GBP'.
payout(Breakdown, Policy, quantity(PayoutAmount, gbp)) :-
    breakdown_coverage(Breakdown, Policy, covered),
    breakdown_limit(Breakdown, Policy, quantity(PayoutAmountMax, gbp), max),
    expenses_payout(Breakdown, Policy, quantity(ExpensesPayoutAmount, gbp)),
    PayoutAmount is min(ExpensesPayoutAmount, PayoutAmountMax).

sum_expenses([], _Policy, quantity(0, gbp)).
sum_expenses([Expense|Tail], Policy, quantity(TotalAmount, gbp)) :-
    expense_coverage(Expense, Policy, covered),
    limited_expense_payout(Expense, Policy, quantity(PayoutAmount, gbp)),
    sum_expenses(Tail, Policy, quantity(TailAmount, gbp)),
    TotalAmount is PayoutAmount + TailAmount.

breakdown_coverage(Breakdown, Policy, covered) :-
    breakdown_covered(Breakdown, Policy),
    not breakdown_excluded(Breakdown, Policy, _).

breakdown_coverage(Breakdown, Policy, excluded) :-
    breakdown_excluded(Breakdown, Policy, _).

expense_coverage(Expense, Policy, covered) :-
    expense_covered(Expense, Policy),
    not expense_excluded(Expense, Policy, _).

expense_coverage(Expense, Policy, excluded) :-
  expense_excluded(Expense, Policy, _).

% Expenses with no limits
expense_payout(Expense, Policy, Payout) :-
  expense_category(Expense, Category), expense_category_unlimited(Category),
  expense_coverage(Expense, Policy, covered),
  expense_amount(Expense, Payout).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Utilities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

breakdown_expense(Breakdown, Expense) :-
    breakdown_expenses(Breakdown, Expenses), member(Expense, Expenses).

list_length([], 0).
list_length([_Head|Tail], Length) :-
    list_length(Tail, TailLength),
    Length is TailLength + 1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Test data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

vehicle_type(my_vehicle, "car").
vehicle_age(my_vehicle, 10).
vehicle_length(my_vehicle, 4).
vehicle_width(my_vehicle, 2).
vehicle_height(my_vehicle, 1.5).
vehicle_weight(my_vehicle, 2000).
vehicle_registered_uk(my_vehicle, true).
vehicle_commercial(my_vehicle, false).
vehicle_serviced_regularly(my_vehicle).
vehicle_good_condition(my_vehicle).
policy_start(my_policy, 0).
policy_end(my_policy, 31536000).
policy_vehicle(my_policy, my_vehicle).
policy_excess(my_policy, 50).
insuree_home(my_policy, croydon).
location_territory(croydon, uk).
location_territory(wembley, uk).
location_territory(london, uk).
location_distance_to(croydon, london, 10).
location_distance_to(wembley, london, 12).

% Mechanical breakdown scenario
breakdown_vehicle(mech_breakdown, my_vehicle).
breakdown_reason(mech_breakdown, mechanical).
breakdown_time(mech_breakdown, 172800).
breakdown_location(mech_breakdown, wembley).
breakdown_excess_paid(mech_breakdown, my_policy).
breakdown_expenses(mech_breakdown, [bv, vr, vrm, pr]).
expense_category(bv, breakdown_vehicle).
expense_price(bv, quantity(200, gbp)).
breakdown_unrepairable_on_site(mech_breakdown).
expense_category(vr, vehicle_recovery).
expense_price(vr, quantity(50, gbp)).
expense_category(vrm, vehicle_recovery_mileage).
expense_quantities(vrm, [quantity(25, mile)]).
expense_unit_price(vrm, quantity(5, gbp)).
expense_category(pr, passenger_recovery).
expense_quantities(pr, [quantity(5, person), quantity(25, mile)]).
expense_unit_price(pr, quantity(1, gbp)).
expense_category(msg_expense, message).
expense_message(msg_expense, msg).
message_to(msg, croydon).

% Misfueling scenario
breakdown_vehicle(misfuel_breakdown, my_vehicle).
breakdown_reason(misfuel_breakdown, misfuel).
breakdown_time(misfuel_breakdown, 10).
breakdown_location(misfuel_breakdown, wembley).
breakdown_excess_paid(misfuel_breakdown, my_policy).
breakdown_expenses(misfuel_breakdown, [rf]).
expense_category(ff, fuel_flush).
expense_price(ff, quantity(100, gbp)).
expense_category(rf, refuel).
expense_quantities(rf, [quantity(20, liter)]).
expense_unit_price(rf, quantity(2, gbp)).
