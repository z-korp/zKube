import { ComponentValue } from "@dojoengine/recs";
import { shortenHex } from "@dojoengine/utils";
import { Bonus, Condition } from "../types/bonus";
import {
  STREAK_1_7_MULTIPLIER_START,
  STREAK_1_7_MULTIPLIER_INCREMENT,
  STREAK_8_30_MULTIPLIER_START,
  STREAK_8_30_MULTIPLIER_INCREMENT,
  MULTIPLIER_SCALE,
  LEVEL_MULTIPLIER_INCREMENT,
  LEVEL_MULTIPLIER_START,
  ACCOUNT_AGE_MULTIPLIER_INCREMENT,
  ACCOUNT_AGE_MULTIPLIER_START,
  ACCOUNT_AGE_MULTIPLIER_CAP,
  STREAK_31_PLUS_MULTIPLIER_INCREMENT,
  STREAK_31_PLUS_MULTIPLIER_START,
  STREAK_MULTIPLIER_CAP,
} from "../constants";
import { Level } from "../types/level";

export interface BonusDetail {
  bonus: Bonus;
  score: number;
  combo: number;
  description: string;
  name: string;
  has: boolean;
}

export class Player {
  public id: string;
  public game_id: string;
  public name: string;
  public points: number;
  public daily_streak: number;
  public last_active_day: number;
  public account_creation_day: number;

  constructor(player: ComponentValue, name: string) {
    // It's weird but it seems that depending on the method use to extract the data
    // the types are parsed differently
    // usePlayer use useComponentValue which seems to return a bigint
    // usePlayerList use useEntityQuery + getComponentValue which seems to return a string
    // didn't dig more
    if (typeof player.id === "bigint") {
      this.id = player.id.toString(16);
    } else {
      this.id = player.id;
    }

    /*if (typeof player.name === "bigint") {
      this.name = shortString.decodeShortString(player.name.toString());
    } else {
      this.name = player.name;
    }*/

    this.name = name;
    this.game_id = player.game_id;
    this.points = player.points;
    this.daily_streak = player.daily_streak;
    this.last_active_day = player.last_active_day;
    this.account_creation_day = player.account_creation_day;
  }

  public getShortAddress(): string {
    return shortenHex(this.id);
  }

  public static getBonuses({
    counts = [0, 0, 0],
  }: {
    counts?: number[];
  }): BonusDetail[] {
    const details: BonusDetail[] = [];
    const bonuses = Bonus.getBonuses();
    bonuses.forEach((bonus, bonus_index) => {
      const count = bonus_index < counts.length ? counts[bonus_index] : 0;
      const conditions: Condition[] = bonus.getConditions();
      const description = bonus.getDescription();
      const name = bonus.getName();
      const bonus_conditions = conditions.map((condition, index) => {
        return {
          bonus,
          score: condition.score,
          combo: condition.combo,
          description,
          name: `${name} ${index + 1}`,
          has: count > index,
        };
      });
      // console.log(`Bonus: ${name}, Count: ${count}`);
      details.push(...bonus_conditions);
    });
    return details;
  }

  public getDailyStreakMultiplier(): number {
    const streak = this.daily_streak;

    if (streak >= 1 && streak <= 7) {
      return (
        STREAK_1_7_MULTIPLIER_START +
        (streak - 1) * STREAK_1_7_MULTIPLIER_INCREMENT
      );
    } else if (streak >= 8 && streak <= 30) {
      return (
        STREAK_8_30_MULTIPLIER_START +
        (streak - 8) * STREAK_8_30_MULTIPLIER_INCREMENT
      );
    } else if (streak >= 31) {
      const multiplier =
        STREAK_31_PLUS_MULTIPLIER_START +
        (streak - 31) * STREAK_31_PLUS_MULTIPLIER_INCREMENT;
      return Math.min(multiplier, STREAK_MULTIPLIER_CAP); // Cap the multiplier at 1.40x
    } else {
      return MULTIPLIER_SCALE; // Default to 1.00x if no streak
    }
  }

  public getLevelMultiplier(): number {
    const level = Level.fromPoints(this.points).value;

    return LEVEL_MULTIPLIER_START + level * LEVEL_MULTIPLIER_INCREMENT;
  }

  public getAccountAgeInDays(): number {
    const currentDay = Math.floor(Date.now() / 1000 / 86400);
    return Math.floor(currentDay - this.account_creation_day);
  }

  public getLevel(): number {
    return Level.fromPoints(this.points).value;
  }

  public getAccountAgeMultiplier(): number {
    const accountAge = this.getAccountAgeInDays();

    if (accountAge < 120) {
      return (
        ACCOUNT_AGE_MULTIPLIER_START +
        accountAge * ACCOUNT_AGE_MULTIPLIER_INCREMENT
      );
    } else {
      return ACCOUNT_AGE_MULTIPLIER_CAP;
    }
  }
}
