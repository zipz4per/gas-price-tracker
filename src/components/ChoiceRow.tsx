import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

/**
 * A horizontal row of options, one of which is selected.
 *
 * The options come from the caller, which gets them from the registry. Nothing
 * here invents a locality or a fuel type — offering one the read path does not
 * recognise turns a tap into a 22023.
 */
export function ChoiceRow<T extends string>({
  label,
  options,
  selected,
  onSelect,
}: {
  label: string;
  options: { value: T; label: string }[];
  selected: T | null;
  onSelect: (value: T) => void;
}) {
  return (
    <View style={styles.group}>
      <Text style={styles.label}>{label}</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <View style={styles.options}>
          {options.map((option) => {
            const isSelected = option.value === selected;
            return (
              <Pressable
                key={option.value}
                accessibilityRole="button"
                accessibilityState={{ selected: isSelected }}
                onPress={() => onSelect(option.value)}
                style={[styles.chip, isSelected && styles.chipSelected]}
              >
                <Text style={[styles.chipText, isSelected && styles.chipTextSelected]}>
                  {option.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  group: {
    gap: 6,
  },
  label: {
    fontSize: 11,
    textTransform: 'uppercase',
    letterSpacing: 0.6,
    color: '#6B6B6B',
  },
  options: {
    flexDirection: 'row',
    gap: 8,
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#C9C9C9',
  },
  chipSelected: {
    backgroundColor: '#1F1F1F',
    borderColor: '#1F1F1F',
  },
  chipText: {
    fontSize: 14,
    color: '#1F1F1F',
  },
  chipTextSelected: {
    color: '#FFFFFF',
    fontWeight: '600',
  },
});
