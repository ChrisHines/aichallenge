-- update rankings

-- a new game and a set of game_player rows have been added
-- the submissions in the game have been updated with new mu and sigma

-- we are now reordering the active submissions ranks, and updating the relative rank_change
-- then we will write the new rank to the rank_after in the game_player data
-- then we will reset the rank change an absolute value for the submissions in the game

-- those not in the game with changed ranks will not have the historical data of all the changes
-- their last game will only show the before and after as it was affected by that game
-- their submission record will show slight changes if they are moved in the rankings by other bots
-- their next game's rank_before will show the change due to other games from their last games rank_after

drop procedure if exists update_rankings;
delimiter $$
create procedure update_rankings(in new_game_id int)
begin

-- reorder all active submmissions
update submission
inner join (
    select 
           s.submission_id,
           @skill := mu - sigma * 3 as skill,
           @seq := (@seq + 1) as seq,
           if(@skill = @last_skill, @last_rank, @seq) as new_rank,
           rank - if(@skill = @last_skill, @last_rank, @seq) as new_rank_change,
           if(@skill = @last_skill, @last_rank, @last_rank := @seq) next_rank,
           @last_skill := @skill
    from (
        select * 
        from submission s 
        where s.latest = 1 
        order by s.mu - s.sigma * 3 desc
    ) s, 
    (select @skill := 0.0) k,
    (select @seq := 0) r, 
    (select @last_skill := null) lk, 
    (select @last_rank := 0) lr 
) s2
    on submission.submission_id = s2.submission_id
set rank = s2.new_rank,
    rank_change = rank_change + s2.new_rank_change
where submission.latest = 1;

-- update game_player rank_after for the game
update game_player
inner join submission s
    on s.submission_id = game_player.submission_id
set rank_after = s.rank
where game_player.game_id = new_game_id;

-- reset rank_change to absolute value for submissions in the game
-- update max game ids
update submission
inner join game_player gp
    on gp.submission_id = submission.submission_id
    and gp.game_id = new_game_id
set rank_change = gp.rank_before - gp.rank_after,
    max_game_id = new_game_id,
    game_count = game_count + 1;

-- update min game ids
update submission
inner join game_player gp
    on gp.submission_id = submission.submission_id
    and gp.game_id = new_game_id
set min_game_id = new_game_id,
    game_count = 1
where min_game_id is null;

end$$
delimiter ;
