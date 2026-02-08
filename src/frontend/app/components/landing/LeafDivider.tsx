import { motion } from "framer-motion";
import { C } from "../../lib/theme";

export function LeafDivider({ color = C.glow }: { color?: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, scaleX: 0 }}
      whileInView={{ opacity: 1, scaleX: 1 }}
      viewport={{ once: true, amount: 0.5 }}
      transition={{ duration: 1, ease: "easeOut" }}
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
        padding: "40px 0",
        transformOrigin: "center",
      }}
    >
      <div
        style={{
          flex: 1,
          maxWidth: 160,
          height: 1,
          background: `linear-gradient(90deg, transparent, ${color}44)`,
        }}
      />
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
        <path
          d="M12 2C10 2 8 5 8 9C8 13 10 18 12 21C14 18 16 13 16 9C16 5 14 2 12 2Z"
          fill={color}
          fillOpacity={0.3}
          stroke={color}
          strokeWidth="0.8"
          strokeOpacity={0.5}
        />
      </svg>
      <div
        style={{
          flex: 1,
          maxWidth: 160,
          height: 1,
          background: `linear-gradient(90deg, ${color}44, transparent)`,
        }}
      />
    </motion.div>
  );
}
