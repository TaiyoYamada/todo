import SharedCore
import SwiftUI

extension View {
    /// ロックするアプリを選ぶ画面を出す。
    ///
    /// 実機では OS の選択画面(FamilyActivityPicker)を、シミュレータでは `simulated` の内容を出す。
    /// 選んだ内容は端末の中にだけ保存され、アプリからは「どのアプリか」を知ることができない。
    public func shieldAppPicker(
        isPresented: Binding<Bool>,
        onChange: @escaping () -> Void,
        @ViewBuilder simulated: @escaping () -> some View
    ) -> some View {
        modifier(ShieldAppPickerModifier(isPresented: isPresented, onChange: onChange, simulated: simulated))
    }
}

#if canImport(FamilyControls) && !targetEnvironment(simulator)
    import FamilyControls

    private struct ShieldAppPickerModifier<Simulated: View>: ViewModifier {
        @Binding var isPresented: Bool
        let onChange: () -> Void
        let simulated: () -> Simulated
        @State private var selection = SelectionStore.load()

        func body(content: Content) -> some View {
            content
                .familyActivityPicker(isPresented: $isPresented, selection: $selection)
                .onChange(of: selection) { _, newValue in
                    SelectionStore.save(newValue)
                    onChange()
                }
        }
    }
#else
    private struct ShieldAppPickerModifier<Simulated: View>: ViewModifier {
        @Binding var isPresented: Bool
        let onChange: () -> Void
        let simulated: () -> Simulated

        func body(content: Content) -> some View {
            content.sheet(isPresented: $isPresented, onDismiss: onChange) {
                simulated()
                    .presentationDetents([.medium])
            }
        }
    }
#endif
